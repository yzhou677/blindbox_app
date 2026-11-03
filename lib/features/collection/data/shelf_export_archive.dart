import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'package:archive/archive_io.dart';
import 'package:blindbox_app/features/collection/application/shelf_backup_commit.dart';
import 'package:blindbox_app/features/collection/data/shelf_media_vault.dart';
import 'package:blindbox_app/features/collection/data/shelf_vault_refs.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/collection/persistence/collection_snapshot_codec.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Full shelf export zip (originals + thumbs) — distinct from recovery packs.
///
/// Layout:
/// ```
/// shelfy_shelf_export/
///   manifest.json
///   collection_snapshot_v1.json
///   collection_memory.json
///   collection_shelf_ui_prefs.json
///   originals/<vaultId>.<ext>
///   thumbs/<vaultId>.jpg
/// ```
abstract final class ShelfExportArchive {
  ShelfExportArchive._();

  static const rootFolderName = 'shelfy_shelf_export';
  static const manifestFileName = 'manifest.json';
  static const snapshotFileName = 'collection_snapshot_v1.json';
  static const memoryFileName = 'collection_memory.json';
  static const uiPrefsFileName = 'collection_shelf_ui_prefs.json';
  static const originalsDirName = 'originals';
  static const thumbsDirName = 'thumbs';

  static const kind = 'shelf_export';
  static const schemaVersion = 1;
  static const supportedSchemaVersions = {1};

  /// Soft warn threshold for export size (4b UI).
  static const warnBytes = 500 * 1024 * 1024;

  /// Hard reject for export planned size and unpack total.
  static const rejectBytes = 2 * 1024 * 1024 * 1024;

  static const maxEntries = 20000;
  static const maxSingleFileBytes = 512 * 1024 * 1024;

  /// Keep in sync with pubspec `version` (no package_info dependency).
  static const defaultAppVersion = '1.0.14+27';

  @visibleForTesting
  static Directory? testCacheOverride;

  @visibleForTesting
  static int? testRejectBytesOverride;

  @visibleForTesting
  static int? testWarnBytesOverride;

  @visibleForTesting
  static int? testMaxEntriesOverride;

  @visibleForTesting
  static int? testMaxSingleFileBytesOverride;

  @visibleForTesting
  static void resetForTest({bool clearCacheOverride = true}) {
    if (clearCacheOverride) {
      testCacheOverride = null;
    }
    testRejectBytesOverride = null;
    testWarnBytesOverride = null;
    testMaxEntriesOverride = null;
    testMaxSingleFileBytesOverride = null;
  }

  static int get _rejectBytes => testRejectBytesOverride ?? rejectBytes;
  static int get _warnBytes => testWarnBytesOverride ?? warnBytes;
  static int get _maxEntries => testMaxEntriesOverride ?? maxEntries;
  static int get _maxSingleFileBytes =>
      testMaxSingleFileBytesOverride ?? maxSingleFileBytes;

  static String get _sep => Platform.pathSeparator;

  /// Progress: [completed] files processed out of [total].
  static Future<ShelfExportWriteResult> exportToZip({
    required CollectionSnapshot snapshot,
    required String memoryJson,
    required String uiPrefsJson,
    String? outputPath,
    String appVersion = defaultAppVersion,
    DateTime? createdAtUtc,
    void Function(int completed, int total)? onProgress,
  }) async {
    if (kIsWeb) {
      throw UnsupportedError('Shelf export is not supported on web');
    }

    await ShelfMediaVault.ensureReady();
    final createdAt = (createdAtUtc ?? DateTime.now().toUtc()).toUtc();
    final plan = await _buildMediaPlan(snapshot);

    final snapshotJson = CollectionSnapshotCodec.encode(snapshot);
    final jsonBytes =
        utf8.encode(snapshotJson).length +
        utf8.encode(memoryJson).length +
        utf8.encode(uiPrefsJson).length +
        256; // manifest headroom
    final plannedUncompressed = plan.plannedBytes + jsonBytes;

    if (plannedUncompressed > _rejectBytes) {
      return ShelfExportWriteResult.rejected(
        uncompressedBytes: plannedUncompressed,
        mediaIncomplete: plan.mediaIncomplete,
        reason: ShelfExportRejectReason.tooLarge,
      );
    }

    final cache = await _cacheRoot();
    final stamp = createdAt.millisecondsSinceEpoch;
    final staging = Directory(
      '${cache.path}${_sep}shelf_export_staging_$stamp',
    );
    final zipPath =
        outputPath ??
        '${cache.path}${_sep}shelf_export_$stamp.zip';

    if (await staging.exists()) {
      await staging.delete(recursive: true);
    }
    await staging.create(recursive: true);
    final exportRoot = Directory('${staging.path}$_sep$rootFolderName');
    await exportRoot.create(recursive: true);
    await Directory(
      '${exportRoot.path}$_sep$originalsDirName',
    ).create(recursive: true);
    await Directory(
      '${exportRoot.path}$_sep$thumbsDirName',
    ).create(recursive: true);

    final total = plan.items.length + 4; // media + 4 json files
    var completed = 0;
    void tick() {
      completed += 1;
      onProgress?.call(completed.clamp(0, total), total);
    }

    try {
      var originalCount = 0;
      var thumbCount = 0;
      for (final item in plan.items) {
        if (item.originalSource != null) {
          final dest = File(
            '${exportRoot.path}$_sep$originalsDirName$_sep${item.originalFileName}',
          );
          await File(item.originalSource!).copy(dest.path);
          originalCount += 1;
        }
        if (item.thumbSource != null) {
          final dest = File(
            '${exportRoot.path}$_sep$thumbsDirName$_sep${item.id}.jpg',
          );
          await File(item.thumbSource!).copy(dest.path);
          thumbCount += 1;
        }
        tick();
      }

      final manifest = ShelfExportManifest(
        kind: kind,
        schemaVersion: schemaVersion,
        createdAt: createdAt,
        appVersion: appVersion,
        seriesCount: snapshot.shelfSeries.length,
        figureCount: snapshot.totalShelfFigures,
        originalCount: originalCount,
        thumbCount: thumbCount,
        mediaIncomplete: plan.mediaIncomplete,
      );
      await File(
        '${exportRoot.path}$_sep$manifestFileName',
      ).writeAsString(jsonEncode(manifest.toJson()), flush: true);
      tick();
      await File(
        '${exportRoot.path}$_sep$snapshotFileName',
      ).writeAsString(snapshotJson, flush: true);
      tick();
      await File(
        '${exportRoot.path}$_sep$memoryFileName',
      ).writeAsString(memoryJson, flush: true);
      tick();
      await File(
        '${exportRoot.path}$_sep$uiPrefsFileName',
      ).writeAsString(uiPrefsJson, flush: true);
      tick();

      final zipOut = File(zipPath);
      if (await zipOut.exists()) {
        await zipOut.delete();
      }
      await Isolate.run(
        () => _zipExportStagingSync(
          stagingPath: staging.path,
          zipPath: zipPath,
          rootFolderName: rootFolderName,
        ),
      );

      final zipBytes = await zipOut.length();
      if (zipBytes > _rejectBytes) {
        await zipOut.delete();
        return ShelfExportWriteResult.rejected(
          uncompressedBytes: plannedUncompressed,
          mediaIncomplete: plan.mediaIncomplete,
          reason: ShelfExportRejectReason.tooLarge,
        );
      }

      onProgress?.call(total, total);
      return ShelfExportWriteResult.written(
        zipPath: zipPath,
        uncompressedBytes: plannedUncompressed,
        zipBytes: zipBytes,
        mediaIncomplete: plan.mediaIncomplete,
        exceedsWarnThreshold:
            plannedUncompressed > _warnBytes || zipBytes > _warnBytes,
        originalCount: originalCount,
        thumbCount: thumbCount,
      );
    } finally {
      if (await staging.exists()) {
        try {
          await staging.delete(recursive: true);
        } on Object {
          // best-effort cleanup
        }
      }
    }
  }

  /// Unpacks [zipPath] into a validated staging directory (does not commit).
  static Future<ShelfExportStaging> unpackToStaging(String zipPath) async {
    if (kIsWeb) {
      throw UnsupportedError('Shelf export is not supported on web');
    }
    final zipFile = File(zipPath);
    if (!await zipFile.exists()) {
      throw ShelfExportException('zip file missing');
    }

    // Read fully then decode so Windows releases the zip handle before
    // callers delete temp dirs (InputFileStream can keep locks open).
    final zipBytes = await zipFile.readAsBytes();
    late final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(
        zipBytes,
        verify: true,
        throwOnError: true,
      );
    } on Object catch (e) {
      throw ShelfExportException('zip corrupt or CRC failed: $e');
    }

    try {
      if (archive.files.length > _maxEntries) {
        throw ShelfExportException('too many zip entries');
      }

      final cache = await _cacheRoot();
      final staging = Directory(
        '${cache.path}${_sep}shelf_export_unpack_${DateTime.now().toUtc().millisecondsSinceEpoch}',
      );
      if (await staging.exists()) {
        await staging.delete(recursive: true);
      }
      await staging.create(recursive: true);

      var extractedBytes = 0;
      try {
        for (final entry in archive.files) {
          final rawName = entry.name;
          if (entry.isDirectory ||
              rawName.endsWith('/') ||
              rawName.endsWith('\\')) {
            continue;
          }
          _assertSafeEntryPath(rawName);
          final name = rawName.replaceAll('\\', '/');
          final size = entry.size;
          if (size < 0 || size > _maxSingleFileBytes) {
            throw ShelfExportException('entry too large: $name');
          }
          extractedBytes += size;
          if (extractedBytes > _rejectBytes) {
            throw ShelfExportException('extracted size exceeds limit');
          }

          final bytes = entry.readBytes();
          if (bytes == null) {
            throw ShelfExportException('failed to read entry: $name');
          }
          if (bytes.length > _maxSingleFileBytes) {
            throw ShelfExportException('entry too large: $name');
          }
          await _writeStagingFile(staging, name, bytes);
        }

        final exportRoot = Directory('${staging.path}$_sep$rootFolderName');
        final manifestFile = File(
          '${exportRoot.path}$_sep$manifestFileName',
        );
        final snapshotFile = File(
          '${exportRoot.path}$_sep$snapshotFileName',
        );
        if (!await manifestFile.exists()) {
          throw ShelfExportException('missing manifest');
        }
        if (!await snapshotFile.exists()) {
          throw ShelfExportException('missing snapshot');
        }

        final manifest = ShelfExportManifest.fromJson(
          jsonDecode(await manifestFile.readAsString()) as Object?,
        );
        if (manifest == null) {
          throw ShelfExportException('invalid manifest');
        }
        if (manifest.kind != kind) {
          throw ShelfExportException('unsupported kind: ${manifest.kind}');
        }
        if (!supportedSchemaVersions.contains(manifest.schemaVersion)) {
          throw ShelfExportException(
            'unsupported schemaVersion: ${manifest.schemaVersion}',
          );
        }

        final snapshotJson = await snapshotFile.readAsString();
        final snapshot = CollectionSnapshotCodec.tryDecode(snapshotJson);
        if (snapshot == null) {
          throw ShelfExportException('invalid snapshot');
        }

        final memoryFile = File('${exportRoot.path}$_sep$memoryFileName');
        final uiPrefsFile = File('${exportRoot.path}$_sep$uiPrefsFileName');
        final memoryJson = await memoryFile.exists()
            ? await memoryFile.readAsString()
            : '{}';
        final uiPrefsJson = await uiPrefsFile.exists()
            ? await uiPrefsFile.readAsString()
            : '{}';

        final originalsDir = Directory(
          '${exportRoot.path}$_sep$originalsDirName',
        );
        final thumbsDir = Directory('${exportRoot.path}$_sep$thumbsDirName');
        final originals = <String, File>{};
        final thumbs = <String, File>{};
        if (await originalsDir.exists()) {
          await for (final entity in originalsDir.list()) {
            if (entity is! File) continue;
            final base = entity.uri.pathSegments.last;
            final id = _idFromMediaFileName(base);
            if (id == null) {
              throw ShelfExportException('invalid original name: $base');
            }
            originals[id] = entity;
          }
        }
        if (await thumbsDir.exists()) {
          await for (final entity in thumbsDir.list()) {
            if (entity is! File) continue;
            final base = entity.uri.pathSegments.last;
            final id = _idFromMediaFileName(base);
            if (id == null || !base.toLowerCase().endsWith('.jpg')) {
              throw ShelfExportException('invalid thumb name: $base');
            }
            thumbs[id] = entity;
          }
        }

        return ShelfExportStaging(
          stagingDir: staging,
          manifest: manifest,
          snapshot: snapshot,
          memoryJson: memoryJson,
          uiPrefsJson: uiPrefsJson,
          originalFiles: originals,
          thumbFiles: thumbs,
          extractedBytes: extractedBytes,
        );
      } catch (e) {
        if (await staging.exists()) {
          try {
            await staging.delete(recursive: true);
          } on Object {
            // best-effort
          }
        }
        if (e is ShelfExportException) rethrow;
        throw ShelfExportException('unpack failed: $e');
      }
    } finally {
      for (final entry in archive.files) {
        entry.closeSync();
      }
    }
  }

  /// Commits a validated staging directory (Replace). Deletes staging after.
  static Future<CollectionSnapshot> commitStaging(
    ShelfExportStaging staging,
  ) async {
    try {
      return await ShelfBackupCommit.apply(
        snapshot: staging.snapshot,
        memoryJson: staging.memoryJson,
        uiPrefsJson: staging.uiPrefsJson,
        manageGate: true,
        installMedia: () async {
          await ShelfMediaVault.ensureReady();
          final ids = <String>{
            ...staging.originalFiles.keys,
            ...staging.thumbFiles.keys,
          };
          for (final id in ids) {
            final original = staging.originalFiles[id];
            final thumb = staging.thumbFiles[id];
            if (original != null) {
              final bytes = await original.readAsBytes();
              if (bytes.isEmpty) continue;
              final ext = _extensionOfFileName(original.uri.pathSegments.last);
              final thumbBytes = thumb == null
                  ? null
                  : await thumb.readAsBytes();
              await ShelfMediaVault.installExportedOriginal(
                id: id,
                originalBytes: bytes,
                ext: ext,
                thumbBytes: thumbBytes,
              );
            } else if (thumb != null) {
              final bytes = await thumb.readAsBytes();
              if (bytes.isEmpty) continue;
              await ShelfMediaVault.installRecoveredThumb(
                id: id,
                thumbBytes: bytes,
              );
            }
          }
        },
        transformSnapshot: (snap) {
          // Thumb-only installs land as .jpg — rewrite those ids only.
          final thumbOnly = <String>{};
          for (final id in staging.thumbFiles.keys) {
            if (!staging.originalFiles.containsKey(id)) {
              thumbOnly.add(id);
            }
          }
          if (thumbOnly.isEmpty) return snap;
          return snap.copyWith(
            shelfSeries: [
              for (final series in snap.shelfSeries)
                ShelfSeries(
                  id: series.id,
                  name: series.name,
                  brand: series.brand,
                  ipName: series.ipName,
                  figures: [
                    for (final figure in series.figures)
                      ShelfFigure(
                        id: figure.id,
                        seriesId: figure.seriesId,
                        name: figure.name,
                        imageUrl: figure.imageUrl,
                        localImageUri: _rewriteIfThumbOnly(
                          figure.localImageUri,
                          thumbOnly,
                        ),
                        rarity: figure.rarity,
                        isSecret: figure.isSecret,
                        rarityLabel: figure.rarityLabel,
                        imageKey: figure.imageKey,
                        taxonomyBrandId: figure.taxonomyBrandId,
                        taxonomyIpId: figure.taxonomyIpId,
                        catalogFigureTemplateId: figure.catalogFigureTemplateId,
                      ),
                  ],
                  shelfAccent: series.shelfAccent,
                  notes: series.notes,
                  catalogTemplateId: series.catalogTemplateId,
                  taxonomyBrandId: series.taxonomyBrandId,
                  taxonomyIpId: series.taxonomyIpId,
                  imageKey: series.imageKey,
                  customCoverImageUri: _rewriteIfThumbOnly(
                    series.customCoverImageUri,
                    thumbOnly,
                  ),
                  releaseDate: series.releaseDate,
                ),
            ],
          );
        },
      );
    } finally {
      await staging.delete();
    }
  }

  static String? _rewriteIfThumbOnly(String? ref, Set<String> thumbOnly) {
    final id = ShelfMediaVault.idFromRef(ref);
    if (id == null || !thumbOnly.contains(id)) return ref;
    return ShelfMediaVault.recoveredJpgRef(ref);
  }

  static Future<_MediaPlan> _buildMediaPlan(CollectionSnapshot snapshot) async {
    final ids = ShelfVaultRefs.referencedIds(snapshot);
    final items = <_MediaPlanItem>[];
    var plannedBytes = 0;
    var mediaIncomplete = false;

    for (final id in ids) {
      final paths = await ShelfMediaVault.pathsForId(id);
      String? originalSource;
      String? originalFileName;
      String? thumbSource;

      if (paths.originalPath != null &&
          await File(paths.originalPath!).exists()) {
        originalSource = paths.originalPath;
        originalFileName = originalSource!.split(RegExp(r'[/\\]')).last;
        plannedBytes += await File(originalSource).length();
      } else {
        mediaIncomplete = true;
      }

      if (paths.thumbPath != null && await File(paths.thumbPath!).exists()) {
        thumbSource = paths.thumbPath;
        plannedBytes += await File(thumbSource!).length();
      } else if (paths.vaultRef != null) {
        // Referenced but no thumb either — still incomplete if original gone.
        if (originalSource == null) {
          mediaIncomplete = true;
        }
      } else {
        mediaIncomplete = true;
      }

      if (originalSource == null && thumbSource == null) {
        continue;
      }
      items.add(
        _MediaPlanItem(
          id: id,
          originalSource: originalSource,
          originalFileName: originalFileName ?? '$id.jpg',
          thumbSource: thumbSource,
        ),
      );
    }

    return _MediaPlan(
      items: items,
      plannedBytes: plannedBytes,
      mediaIncomplete: mediaIncomplete,
    );
  }

  static Future<Directory> _cacheRoot() async {
    final base = testCacheOverride ?? await getTemporaryDirectory();
    final dir = Directory('${base.path}${_sep}shelf_export');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  static Future<void> _writeStagingFile(
    Directory staging,
    String relativePosix,
    List<int> bytes,
  ) async {
    final parts = relativePosix.split('/');
    final file = File([staging.path, ...parts].join(_sep));
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes, flush: true);
  }

  static void _assertSafeEntryPath(String name) {
    if (name.contains('\\')) {
      throw ShelfExportException('backslash path rejected: $name');
    }
    final n = name;
    if (n.contains('..')) {
      throw ShelfExportException('path traversal rejected: $n');
    }
    if (n.startsWith('/')) {
      throw ShelfExportException('absolute path rejected: $n');
    }
    if (RegExp(r'^[a-zA-Z]:').hasMatch(n)) {
      throw ShelfExportException('drive path rejected: $n');
    }
    if (n.contains(':')) {
      throw ShelfExportException('colon path rejected: $n');
    }
    if (!_isAllowedRelativePath(n)) {
      throw ShelfExportException('path not on whitelist: $n');
    }
  }

  static bool _isAllowedRelativePath(String n) {
    const prefix = '$rootFolderName/';
    if (!n.startsWith(prefix)) return false;
    final rest = n.substring(prefix.length);
    if (rest == manifestFileName ||
        rest == snapshotFileName ||
        rest == memoryFileName ||
        rest == uiPrefsFileName) {
      return true;
    }
    if (rest.startsWith('$originalsDirName/')) {
      final file = rest.substring(originalsDirName.length + 1);
      return _isSafeMediaFileName(file) && !file.contains('/');
    }
    if (rest.startsWith('$thumbsDirName/')) {
      final file = rest.substring(thumbsDirName.length + 1);
      return _isSafeMediaFileName(file) &&
          !file.contains('/') &&
          file.toLowerCase().endsWith('.jpg');
    }
    return false;
  }

  static final _mediaNameRe = RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]*$');

  static bool _isSafeMediaFileName(String name) {
    if (name.isEmpty || name.contains('/') || name.contains('\\')) {
      return false;
    }
    final dot = name.lastIndexOf('.');
    if (dot <= 0 || dot == name.length - 1) return false;
    return _mediaNameRe.hasMatch(name);
  }

  static String? _idFromMediaFileName(String name) {
    final dot = name.lastIndexOf('.');
    if (dot <= 0) return null;
    final id = name.substring(0, dot);
    if (!_mediaNameRe.hasMatch(name)) return null;
    return id;
  }

  static String _extensionOfFileName(String name) {
    final dot = name.lastIndexOf('.');
    if (dot < 0) return '.jpg';
    return name.substring(dot).toLowerCase();
  }
}

/// Top-level for [Isolate.run].
void _zipExportStagingSync({
  required String stagingPath,
  required String zipPath,
  required String rootFolderName,
}) {
  final staging = Directory(stagingPath);
  final exportRoot = Directory('$stagingPath${Platform.pathSeparator}$rootFolderName');
  if (!exportRoot.existsSync()) {
    throw StateError('export staging missing root folder');
  }
  final encoder = ZipFileEncoder();
  encoder.create(zipPath);
  // Include the root folder name in zip entries.
  encoder.addDirectorySync(exportRoot, includeDirName: true);
  encoder.closeSync();
  // Touch staging so analyzer keeps the param used on all platforms.
  if (!staging.existsSync()) {
    throw StateError('export staging missing');
  }
}

class _MediaPlan {
  const _MediaPlan({
    required this.items,
    required this.plannedBytes,
    required this.mediaIncomplete,
  });

  final List<_MediaPlanItem> items;
  final int plannedBytes;
  final bool mediaIncomplete;
}

class _MediaPlanItem {
  const _MediaPlanItem({
    required this.id,
    required this.originalSource,
    required this.originalFileName,
    required this.thumbSource,
  });

  final String id;
  final String? originalSource;
  final String originalFileName;
  final String? thumbSource;
}

@immutable
class ShelfExportManifest {
  const ShelfExportManifest({
    required this.kind,
    required this.schemaVersion,
    required this.createdAt,
    required this.appVersion,
    required this.seriesCount,
    required this.figureCount,
    required this.originalCount,
    required this.thumbCount,
    required this.mediaIncomplete,
  });

  final String kind;
  final int schemaVersion;
  final DateTime createdAt;
  final String appVersion;
  final int seriesCount;
  final int figureCount;
  final int originalCount;
  final int thumbCount;
  final bool mediaIncomplete;

  Map<String, Object?> toJson() => {
    'kind': kind,
    'schemaVersion': schemaVersion,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'appVersion': appVersion,
    'seriesCount': seriesCount,
    'figureCount': figureCount,
    'originalCount': originalCount,
    'thumbCount': thumbCount,
    'mediaIncomplete': mediaIncomplete,
  };

  static ShelfExportManifest? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final map = Map<String, dynamic>.from(raw);
    final kind = map['kind']?.toString();
    final schemaVersion = map['schemaVersion'];
    final createdRaw = map['createdAt']?.toString();
    final appVersion = map['appVersion']?.toString();
    if (kind == null ||
        schemaVersion is! int ||
        createdRaw == null ||
        appVersion == null) {
      return null;
    }
    final createdAt = DateTime.tryParse(createdRaw)?.toUtc();
    if (createdAt == null) return null;
    return ShelfExportManifest(
      kind: kind,
      schemaVersion: schemaVersion,
      createdAt: createdAt,
      appVersion: appVersion,
      seriesCount: (map['seriesCount'] as num?)?.toInt() ?? 0,
      figureCount: (map['figureCount'] as num?)?.toInt() ?? 0,
      originalCount: (map['originalCount'] as num?)?.toInt() ?? 0,
      thumbCount: (map['thumbCount'] as num?)?.toInt() ?? 0,
      mediaIncomplete: map['mediaIncomplete'] == true,
    );
  }
}

enum ShelfExportRejectReason { tooLarge }

@immutable
class ShelfExportWriteResult {
  const ShelfExportWriteResult._({
    required this.wrote,
    required this.uncompressedBytes,
    required this.mediaIncomplete,
    this.zipPath,
    this.zipBytes = 0,
    this.exceedsWarnThreshold = false,
    this.originalCount = 0,
    this.thumbCount = 0,
    this.rejectReason,
  });

  factory ShelfExportWriteResult.written({
    required String zipPath,
    required int uncompressedBytes,
    required int zipBytes,
    required bool mediaIncomplete,
    required bool exceedsWarnThreshold,
    required int originalCount,
    required int thumbCount,
  }) {
    return ShelfExportWriteResult._(
      wrote: true,
      zipPath: zipPath,
      uncompressedBytes: uncompressedBytes,
      zipBytes: zipBytes,
      mediaIncomplete: mediaIncomplete,
      exceedsWarnThreshold: exceedsWarnThreshold,
      originalCount: originalCount,
      thumbCount: thumbCount,
    );
  }

  factory ShelfExportWriteResult.rejected({
    required int uncompressedBytes,
    required bool mediaIncomplete,
    required ShelfExportRejectReason reason,
  }) {
    return ShelfExportWriteResult._(
      wrote: false,
      uncompressedBytes: uncompressedBytes,
      mediaIncomplete: mediaIncomplete,
      rejectReason: reason,
    );
  }

  final bool wrote;
  final String? zipPath;
  final int uncompressedBytes;
  final int zipBytes;
  final bool mediaIncomplete;
  final bool exceedsWarnThreshold;
  final int originalCount;
  final int thumbCount;
  final ShelfExportRejectReason? rejectReason;
}

class ShelfExportStaging {
  ShelfExportStaging({
    required this.stagingDir,
    required this.manifest,
    required this.snapshot,
    required this.memoryJson,
    required this.uiPrefsJson,
    required this.originalFiles,
    required this.thumbFiles,
    required this.extractedBytes,
  });

  final Directory stagingDir;
  final ShelfExportManifest manifest;
  final CollectionSnapshot snapshot;
  final String memoryJson;
  final String uiPrefsJson;
  final Map<String, File> originalFiles;
  final Map<String, File> thumbFiles;
  final int extractedBytes;

  Future<void> delete() async {
    if (await stagingDir.exists()) {
      await stagingDir.delete(recursive: true);
    }
  }
}

class ShelfExportException implements Exception {
  ShelfExportException(this.message);
  final String message;

  @override
  String toString() => 'ShelfExportException: $message';
}

/// Pre-import safety zips under Application Support `export_backups/`.
///
/// Keeps at most one `pre_import_*.zip`; deletes files older than [retention].
abstract final class ShelfExportBackupStore {
  ShelfExportBackupStore._();

  static const folderName = 'export_backups';
  static const filePrefix = 'pre_import_';
  static const retention = Duration(days: 7);
  static const keepCount = 1;

  @visibleForTesting
  static Directory? testSupportOverride;

  @visibleForTesting
  static DateTime? testNowUtc;

  @visibleForTesting
  static void resetForTest({bool clearSupportOverride = true}) {
    if (clearSupportOverride) {
      testSupportOverride = null;
    }
    testNowUtc = null;
  }

  static Future<Directory> directory() async {
    final base =
        testSupportOverride ?? await getApplicationSupportDirectory();
    final dir = Directory(
      '${base.path}${Platform.pathSeparator}$folderName',
    );
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  static Future<String> nextBackupPath() async {
    final dir = await directory();
    final stamp = (testNowUtc ?? DateTime.now().toUtc())
        .millisecondsSinceEpoch;
    return '${dir.path}${Platform.pathSeparator}$filePrefix$stamp.zip';
  }

  /// Deletes expired backups and trims to [keepCount] newest `pre_import_*.zip`.
  static Future<void> prune() async {
    final dir = await directory();
    if (!await dir.exists()) return;
    final now = (testNowUtc ?? DateTime.now().toUtc()).toUtc();
    final files = <File>[];
    await for (final entity in dir.list()) {
      if (entity is! File) continue;
      final name = entity.uri.pathSegments.last;
      if (!name.startsWith(filePrefix) || !name.endsWith('.zip')) continue;
      final stat = await entity.stat();
      final age = now.difference(stat.modified.toUtc());
      if (age >= retention) {
        await entity.delete();
        continue;
      }
      files.add(entity);
    }
    files.sort(
      (a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()),
    );
    for (var i = keepCount; i < files.length; i++) {
      await files[i].delete();
    }
  }
}
