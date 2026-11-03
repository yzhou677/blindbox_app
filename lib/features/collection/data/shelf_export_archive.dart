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

  /// Zip / unpack staging older than this are purged by [cleanupStaleExports].
  static const staleMaxAge = Duration(days: 1);

  static const unpackStagingPrefix = 'shelf_export_unpack_';

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

  /// Overrides "now" for backup filenames and stale cutoff (tests).
  @visibleForTesting
  static DateTime? testNowOverride;

  @visibleForTesting
  static Duration? testStaleMaxAgeOverride;

  @visibleForTesting
  static void resetForTest({bool clearCacheOverride = true}) {
    if (clearCacheOverride) {
      testCacheOverride = null;
    }
    testRejectBytesOverride = null;
    testWarnBytesOverride = null;
    testMaxEntriesOverride = null;
    testMaxSingleFileBytesOverride = null;
    testNowOverride = null;
    testStaleMaxAgeOverride = null;
  }

  static int get _rejectBytes => testRejectBytesOverride ?? rejectBytes;
  static int get _warnBytes => testWarnBytesOverride ?? warnBytes;
  static int get _maxEntries => testMaxEntriesOverride ?? maxEntries;
  static int get _maxSingleFileBytes =>
      testMaxSingleFileBytesOverride ?? maxSingleFileBytes;
  static Duration get _staleMaxAge =>
      testStaleMaxAgeOverride ?? staleMaxAge;

  static DateTime get _now => testNowOverride ?? DateTime.now();

  static String get _sep => Platform.pathSeparator;

  /// Planned uncompressed size without writing a zip (for 4b warn / reject UI).
  static Future<ShelfExportSizeEstimate> estimateSize({
    required CollectionSnapshot snapshot,
    required String memoryJson,
    required String uiPrefsJson,
  }) async {
    if (kIsWeb) {
      throw UnsupportedError('Shelf export is not supported on web');
    }
    await ShelfMediaVault.ensureReady();
    final plan = await _buildMediaPlan(snapshot);
    final jsonBytes =
        utf8.encode(CollectionSnapshotCodec.encode(snapshot)).length +
        utf8.encode(memoryJson).length +
        utf8.encode(uiPrefsJson).length +
        256;
    return ShelfExportSizeEstimate(
      uncompressedBytes: plan.plannedBytes + jsonBytes,
      mediaIncomplete: plan.mediaIncomplete,
    );
  }

  /// Deletes zip files and unpack staging dirs in the export cache that are
  /// older than [staleMaxAge] (best-effort). Safe to call from app startup
  /// without awaiting first frame.
  static Future<void> cleanupStaleExports({
    DateTime? now,
    Duration? maxAge,
  }) async {
    if (kIsWeb) return;
    try {
      final cache = await _cacheRoot();
      if (!await cache.exists()) return;
      final cutoff = (now ?? _now).subtract(maxAge ?? _staleMaxAge);
      await for (final entity in cache.list(followLinks: false)) {
        try {
          final name = _baseName(entity.path);
          final DateTime modified;
          if (entity is Directory && name.startsWith(unpackStagingPrefix)) {
            modified = _stagingAgeHint(name) ?? (await entity.stat()).modified;
          } else {
            modified = (await entity.stat()).modified;
          }
          if (!modified.isBefore(cutoff)) continue;
          if (entity is File) {
            if (name.toLowerCase().endsWith('.zip')) {
              await entity.delete();
            }
          } else if (entity is Directory) {
            if (name.startsWith(unpackStagingPrefix)) {
              await entity.delete(recursive: true);
            }
          }
        } on Object {
          // skip one entry
        }
      }
    } on Object {
      // best-effort
    }
  }

  /// `Shelfy-backup-YYYY-MM-DD` (local calendar day).
  @visibleForTesting
  static String backupZipStem(DateTime localDate) {
    final y = localDate.year.toString().padLeft(4, '0');
    final m = localDate.month.toString().padLeft(2, '0');
    final d = localDate.day.toString().padLeft(2, '0');
    return 'Shelfy-backup-$y-$m-$d';
  }

  /// Picks `Shelfy-backup-YYYY-MM-DD.zip`, or `-2`, `-3`, … when taken.
  @visibleForTesting
  static String allocateBackupZipFileName({
    required DateTime localDate,
    required bool Function(String fileName) exists,
  }) {
    final stem = backupZipStem(localDate);
    final first = '$stem.zip';
    if (!exists(first)) return first;
    for (var n = 2; n < 10000; n++) {
      final candidate = '$stem-$n.zip';
      if (!exists(candidate)) return candidate;
    }
    throw StateError('too many shelf exports for $stem');
  }

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

    await cleanupStaleExports();
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

    var originalCount = 0;
    var thumbCount = 0;
    final fileEntries = <List<String>>[];
    for (final item in plan.items) {
      if (item.originalSource != null) {
        fileEntries.add([
          item.originalSource!,
          '$rootFolderName/$originalsDirName/${item.originalFileName}',
        ]);
        originalCount += 1;
      }
      if (item.thumbSource != null) {
        fileEntries.add([
          item.thumbSource!,
          '$rootFolderName/$thumbsDirName/${item.id}.jpg',
        ]);
        thumbCount += 1;
      }
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
    final jsonEntries = <String, String>{
      '$rootFolderName/$manifestFileName': jsonEncode(manifest.toJson()),
      '$rootFolderName/$snapshotFileName': snapshotJson,
      '$rootFolderName/$memoryFileName': memoryJson,
      '$rootFolderName/$uiPrefsFileName': uiPrefsJson,
    };

    final cache = await _cacheRoot();
    final String zipPath;
    if (outputPath != null) {
      zipPath = outputPath;
    } else {
      final localDay = _now;
      final fileName = allocateBackupZipFileName(
        localDate: localDay,
        exists: (name) => File('${cache.path}$_sep$name').existsSync(),
      );
      zipPath = '${cache.path}$_sep$fileName';
    }

    final zipOut = File(zipPath);
    if (await zipOut.exists()) {
      await zipOut.delete();
    }

    final total = jsonEntries.length + fileEntries.length;
    onProgress?.call(0, total);

    await Isolate.run(
      () => _zipDirectFromSourcesSync(
        zipPath: zipPath,
        jsonEntries: jsonEntries,
        fileEntries: fileEntries,
      ),
    );

    onProgress?.call(total, total);

    final zipBytes = await zipOut.length();
    if (zipBytes > _rejectBytes) {
      await zipOut.delete();
      return ShelfExportWriteResult.rejected(
        uncompressedBytes: plannedUncompressed,
        mediaIncomplete: plan.mediaIncomplete,
        reason: ShelfExportRejectReason.tooLarge,
      );
    }

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
  }

  /// Unpacks [zipPath] into a validated staging directory (does not commit).
  ///
  /// Decode + extract + path/size checks run inside [Isolate.run]. Limits use
  /// **actual bytes written**, not zip-header sizes alone.
  static Future<ShelfExportStaging> unpackToStaging(String zipPath) async {
    if (kIsWeb) {
      throw UnsupportedError('Shelf export is not supported on web');
    }
    final zipFile = File(zipPath);
    if (!await zipFile.exists()) {
      throw ShelfExportException('zip file missing');
    }

    final cache = await _cacheRoot();
    final stagingPath =
        '${cache.path}$_sep$unpackStagingPrefix${DateTime.now().toUtc().millisecondsSinceEpoch}';

    // Capture limits on this isolate — worker isolates do not see test overrides.
    final maxEntries = _maxEntries;
    final maxSingleFileBytes = _maxSingleFileBytes;
    final rejectBytes = _rejectBytes;

    final isolateResult = await Isolate.run(
      () => _unpackZipStreamingSync(
        zipPath: zipPath,
        stagingPath: stagingPath,
        rootFolderName: rootFolderName,
        maxEntries: maxEntries,
        maxSingleFileBytes: maxSingleFileBytes,
        rejectBytes: rejectBytes,
        manifestFileName: manifestFileName,
        snapshotFileName: snapshotFileName,
        memoryFileName: memoryFileName,
        uiPrefsFileName: uiPrefsFileName,
        originalsDirName: originalsDirName,
        thumbsDirName: thumbsDirName,
      ),
    );

    if (!isolateResult.ok) {
      throw ShelfExportException(isolateResult.error ?? 'unpack failed');
    }

    final staging = Directory(isolateResult.stagingPath!);
    try {
      final exportRoot = Directory('${staging.path}$_sep$rootFolderName');
      final manifestFile = File('${exportRoot.path}$_sep$manifestFileName');
      final snapshotFile = File('${exportRoot.path}$_sep$snapshotFileName');
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

      final originals = <String, File>{
        for (final e in isolateResult.originalPaths.entries) e.key: File(e.value),
      };
      final thumbs = <String, File>{
        for (final e in isolateResult.thumbPaths.entries) e.key: File(e.value),
      };

      return ShelfExportStaging(
        stagingDir: staging,
        manifest: manifest,
        snapshot: snapshot,
        memoryJson: memoryJson,
        uiPrefsJson: uiPrefsJson,
        originalFiles: originals,
        thumbFiles: thumbs,
        extractedBytes: isolateResult.extractedBytes,
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
              if (!await original.exists() || await original.length() == 0) {
                continue;
              }
              final ext = _extensionOfFileName(_baseName(original.path));
              await ShelfMediaVault.installExportedOriginalFromFiles(
                id: id,
                originalFile: original,
                ext: ext,
                thumbFile: thumb,
              );
            } else if (thumb != null) {
              if (!await thumb.exists() || await thumb.length() == 0) {
                continue;
              }
              await ShelfMediaVault.installRecoveredThumbFromFile(
                id: id,
                thumbFile: thumb,
                overwriteOriginal: true,
              );
            }
          }
        },
        transformSnapshot: (snap) {
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
      } else if (paths.vaultRef == null || originalSource == null) {
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

  static String _baseName(String path) {
    final normalized = path.replaceAll('\\', '/');
    final parts = normalized.split('/');
    for (var i = parts.length - 1; i >= 0; i--) {
      if (parts[i].isNotEmpty) return parts[i];
    }
    return path;
  }

  /// Prefer epoch embedded in `shelf_export_unpack_<ms>` names.
  static DateTime? _stagingAgeHint(String dirName) {
    if (!dirName.startsWith(unpackStagingPrefix)) return null;
    final suffix = dirName.substring(unpackStagingPrefix.length);
    final ms = int.tryParse(suffix);
    if (ms == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true).toLocal();
  }

  static String _extensionOfFileName(String name) {
    final dot = name.lastIndexOf('.');
    if (dot < 0) return '.jpg';
    return name.substring(dot).toLowerCase();
  }
}

/// Top-level for [Isolate.run] — zip JSON + vault files without a staging copy.
void _zipDirectFromSourcesSync({
  required String zipPath,
  required Map<String, String> jsonEntries,
  required List<List<String>> fileEntries,
}) {
  final encoder = ZipFileEncoder();
  encoder.create(zipPath);
  try {
    for (final e in jsonEntries.entries) {
      encoder.addArchiveFile(ArchiveFile.string(e.key, e.value));
    }
    for (final pair in fileEntries) {
      final abs = pair[0];
      final entryName = pair[1];
      final file = File(abs);
      if (!file.existsSync()) {
        throw StateError('missing vault file for export: $abs');
      }
      encoder.addFileSync(file, entryName);
    }
  } finally {
    encoder.closeSync();
  }
}

/// Top-level for [Isolate.run] — stream-decode zip to staging with byte caps.
_UnpackIsolateResult _unpackZipStreamingSync({
  required String zipPath,
  required String stagingPath,
  required String rootFolderName,
  required int maxEntries,
  required int maxSingleFileBytes,
  required int rejectBytes,
  required String manifestFileName,
  required String snapshotFileName,
  required String memoryFileName,
  required String uiPrefsFileName,
  required String originalsDirName,
  required String thumbsDirName,
}) {
  final staging = Directory(stagingPath);
  final sep = Platform.pathSeparator;

  void deleteStaging() {
    if (staging.existsSync()) {
      try {
        staging.deleteSync(recursive: true);
      } on Object {
        // best-effort
      }
    }
  }

  InputFileStream? input;
  Archive? archive;
  try {
    if (staging.existsSync()) {
      staging.deleteSync(recursive: true);
    }
    staging.createSync(recursive: true);

    input = InputFileStream(zipPath);
    try {
      archive = ZipDecoder().decodeStream(
        input,
        verify: true,
        throwOnError: true,
      );
    } on Object catch (e) {
      deleteStaging();
      return _UnpackIsolateResult.fail('zip corrupt or CRC failed: $e');
    }

    if (archive.files.length > maxEntries) {
      deleteStaging();
      return _UnpackIsolateResult.fail('too many zip entries');
    }

    var extractedBytes = 0;
    final originalPaths = <String, String>{};
    final thumbPaths = <String, String>{};
    final mediaNameRe = RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]*$');

    bool isSafeMediaFileName(String name) {
      if (name.isEmpty || name.contains('/') || name.contains('\\')) {
        return false;
      }
      final dot = name.lastIndexOf('.');
      if (dot <= 0 || dot == name.length - 1) return false;
      return mediaNameRe.hasMatch(name);
    }

    bool isAllowedRelativePath(String n) {
      final prefix = '$rootFolderName/';
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
        return isSafeMediaFileName(file) && !file.contains('/');
      }
      if (rest.startsWith('$thumbsDirName/')) {
        final file = rest.substring(thumbsDirName.length + 1);
        return isSafeMediaFileName(file) &&
            !file.contains('/') &&
            file.toLowerCase().endsWith('.jpg');
      }
      return false;
    }

    void assertSafeEntryPath(String name) {
      if (name.contains('\\')) {
        throw StateError('backslash path rejected: $name');
      }
      if (name.contains('..')) {
        throw StateError('path traversal rejected: $name');
      }
      if (name.startsWith('/')) {
        throw StateError('absolute path rejected: $name');
      }
      if (RegExp(r'^[a-zA-Z]:').hasMatch(name)) {
        throw StateError('drive path rejected: $name');
      }
      if (name.contains(':')) {
        throw StateError('colon path rejected: $name');
      }
      if (!isAllowedRelativePath(name)) {
        throw StateError('path not on whitelist: $name');
      }
    }

    String? idFromMediaFileName(String name) {
      final dot = name.lastIndexOf('.');
      if (dot <= 0) return null;
      if (!mediaNameRe.hasMatch(name)) return null;
      return name.substring(0, dot);
    }

    for (final entry in archive.files) {
      final rawName = entry.name;
      if (entry.isDirectory ||
          rawName.endsWith('/') ||
          rawName.endsWith('\\')) {
        continue;
      }
      assertSafeEntryPath(rawName);
      final name = rawName.replaceAll('\\', '/');

      // Header size is an early reject only — totals use actual writes below.
      if (entry.size < 0 || entry.size > maxSingleFileBytes) {
        throw StateError('entry too large: $name');
      }

      final parts = name.split('/');
      final dest = File([stagingPath, ...parts].join(sep));
      dest.parent.createSync(recursive: true);

      final out = OutputFileStream(dest.path);
      final counter = _LimitedCountingOutput(
        inner: out,
        maxSingleFileBytes: maxSingleFileBytes,
        maxTotalBytes: rejectBytes,
        totalWrittenBefore: extractedBytes,
      );
      try {
        entry.writeContent(counter, freeMemory: true);
        counter.flush();
      } finally {
        out.closeSync();
      }
      extractedBytes = counter.totalWritten;
      entry.closeSync();

      if (name.startsWith('$rootFolderName/$originalsDirName/')) {
        final base = parts.last;
        final id = idFromMediaFileName(base);
        if (id == null) {
          throw StateError('invalid original name: $base');
        }
        originalPaths[id] = dest.path;
      } else if (name.startsWith('$rootFolderName/$thumbsDirName/')) {
        final base = parts.last;
        final id = idFromMediaFileName(base);
        if (id == null || !base.toLowerCase().endsWith('.jpg')) {
          throw StateError('invalid thumb name: $base');
        }
        thumbPaths[id] = dest.path;
      }
    }

    final exportRoot = Directory('$stagingPath$sep$rootFolderName');
    if (!File('$stagingPath$sep$rootFolderName$sep$manifestFileName')
        .existsSync()) {
      throw StateError('missing manifest');
    }
    if (!File('$stagingPath$sep$rootFolderName$sep$snapshotFileName')
        .existsSync()) {
      throw StateError('missing snapshot');
    }
    // Touch exportRoot so empty-media packs still validate path exists.
    if (!exportRoot.existsSync()) {
      throw StateError('missing export root');
    }

    return _UnpackIsolateResult.ok(
      stagingPath: stagingPath,
      extractedBytes: extractedBytes,
      originalPaths: originalPaths,
      thumbPaths: thumbPaths,
    );
  } on Object catch (e) {
    deleteStaging();
    final msg = e is StateError ? e.message : '$e';
    return _UnpackIsolateResult.fail(msg);
  } finally {
    if (archive != null) {
      for (final entry in archive.files) {
        try {
          entry.closeSync();
        } on Object {
          // ignore
        }
      }
    }
    try {
      input?.closeSync();
    } on Object {
      // ignore
    }
  }
}

/// Counts actual bytes written while enforcing single-file and total caps.
class _LimitedCountingOutput extends OutputStream {
  _LimitedCountingOutput({
    required this.inner,
    required this.maxSingleFileBytes,
    required this.maxTotalBytes,
    required int totalWrittenBefore,
  }) : totalWritten = totalWrittenBefore,
       super(byteOrder: ByteOrder.littleEndian);

  final OutputFileStream inner;
  final int maxSingleFileBytes;
  final int maxTotalBytes;
  int totalWritten;
  int fileWritten = 0;

  void _account(int n) {
    if (n <= 0) return;
    fileWritten += n;
    totalWritten += n;
    if (fileWritten > maxSingleFileBytes) {
      throw StateError('entry too large (actual bytes)');
    }
    if (totalWritten > maxTotalBytes) {
      throw StateError('extracted size exceeds limit (actual bytes)');
    }
  }

  @override
  int get length => inner.length;

  @override
  void clear() {
    // Counting wrapper does not own buffered clear semantics.
  }

  @override
  void flush() => inner.flush();

  @override
  Uint8List subset(int start, [int? end]) => inner.subset(start, end);

  @override
  void writeByte(int value) {
    _account(1);
    inner.writeByte(value);
  }

  @override
  void writeBytes(List<int> bytes, {int? length}) {
    final len = length ?? bytes.length;
    _account(len);
    inner.writeBytes(bytes, length: length);
  }

  @override
  void writeStream(InputStream stream) {
    const chunk = 64 * 1024;
    while (!stream.isEOS) {
      final slice = stream.readBytes(chunk);
      final bytes = slice.toUint8List();
      if (bytes.isEmpty) break;
      writeBytes(bytes);
    }
  }
}

class _UnpackIsolateResult {
  const _UnpackIsolateResult._({
    required this.ok,
    this.error,
    this.stagingPath,
    this.extractedBytes = 0,
    this.originalPaths = const {},
    this.thumbPaths = const {},
  });

  factory _UnpackIsolateResult.ok({
    required String stagingPath,
    required int extractedBytes,
    required Map<String, String> originalPaths,
    required Map<String, String> thumbPaths,
  }) {
    return _UnpackIsolateResult._(
      ok: true,
      stagingPath: stagingPath,
      extractedBytes: extractedBytes,
      originalPaths: originalPaths,
      thumbPaths: thumbPaths,
    );
  }

  factory _UnpackIsolateResult.fail(String error) {
    return _UnpackIsolateResult._(ok: false, error: error);
  }

  final bool ok;
  final String? error;
  final String? stagingPath;
  final int extractedBytes;
  final Map<String, String> originalPaths;
  final Map<String, String> thumbPaths;
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
class ShelfExportSizeEstimate {
  const ShelfExportSizeEstimate({
    required this.uncompressedBytes,
    required this.mediaIncomplete,
  });

  final int uncompressedBytes;
  final bool mediaIncomplete;

  bool get exceedsWarnThreshold {
    final warn =
        ShelfExportArchive.testWarnBytesOverride ?? ShelfExportArchive.warnBytes;
    return uncompressedBytes > warn;
  }

  bool get exceedsRejectThreshold {
    final reject =
        ShelfExportArchive.testRejectBytesOverride ??
        ShelfExportArchive.rejectBytes;
    return uncompressedBytes > reject;
  }
}

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
