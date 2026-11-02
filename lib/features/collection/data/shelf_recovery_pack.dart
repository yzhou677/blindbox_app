import 'dart:convert';
import 'dart:io';

import 'package:blindbox_app/features/collection/application/collection_shelf_ui_prefs_provider.dart';
import 'package:blindbox_app/features/collection/data/collection_memory_store.dart';
import 'package:blindbox_app/features/collection/data/shelf_media_vault.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/collection/persistence/collection_snapshot_codec.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Auto-backup recovery pack under Application files `recovery/`.
///
/// On Android, `getApplicationSupportDirectory()` is the app `files/` root, so
/// this lands at `files/recovery/` (the only Auto Backup include path).
///
/// Layout:
/// ```
/// recovery/pack/
///   manifest.json
///   collection_snapshot_v1.json
///   collection_memory.json
///   collection_shelf_ui_prefs.json
///   media/<vaultId>.jpg
/// ```
///
/// Writes stage into `recovery/pack.staging/` then atomically rename-swap so a
/// crash mid-write leaves the previous pack intact. Read expires packs older
/// than [expiry] (default 30 days).
///
/// Catalog art is never packed — only vault thumbs. Snapshot vault refs stay
/// relative (`shelf_media/originals/...`).
abstract final class ShelfRecoveryPack {
  ShelfRecoveryPack._();

  static const folderName = 'recovery';
  static const packDirName = 'pack';
  static const stagingDirName = 'pack.staging';
  static const oldDirName = 'pack.old';

  static const manifestFileName = 'manifest.json';
  static const snapshotFileName = 'collection_snapshot_v1.json';
  static const memoryFileName = 'collection_memory.json';
  static const uiPrefsFileName = 'collection_shelf_ui_prefs.json';
  static const mediaDirName = 'media';

  static const schemaVersion = 1;
  static const expiry = Duration(days: 30);

  /// Keep in sync with pubspec `version` (no package_info dependency).
  static const defaultAppVersion = '1.0.14+27';

  @visibleForTesting
  static Directory? testSupportOverride;

  @visibleForTesting
  static int? testMaxBytesOverride;

  /// Invoked after staging is fully written, before the atomic swap.
  @visibleForTesting
  static Future<void> Function()? testBeforeCommitHook;

  @visibleForTesting
  static DateTime? testNowUtc;

  @visibleForTesting
  static void resetForTest({bool clearSupportOverride = true}) {
    if (clearSupportOverride) {
      testSupportOverride = null;
    }
    testMaxBytesOverride = null;
    testBeforeCommitHook = null;
    testNowUtc = null;
    _rootFuture = null;
  }

  static Future<Directory>? _rootFuture;

  static String get _sep => Platform.pathSeparator;

  static int get maxBytes =>
      testMaxBytesOverride ?? ShelfMediaVault.autoBackupMaxBytes;

  static DateTime get _nowUtc => testNowUtc ?? DateTime.now().toUtc();

  static Future<Directory> _supportRoot() {
    return _rootFuture ??= () async {
      return testSupportOverride ?? await getApplicationSupportDirectory();
    }();
  }

  static Future<Directory> recoveryRoot() async {
    final support = await _supportRoot();
    final dir = Directory('${support.path}$_sep$folderName');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  static Future<Directory> _packDir() async {
    final root = await recoveryRoot();
    return Directory('${root.path}$_sep$packDirName');
  }

  /// Writes a recovery pack for [snapshot] using current memory + UI prefs.
  static Future<ShelfRecoveryWriteResult> write({
    required CollectionSnapshot snapshot,
    String? appVersion,
    String? memoryJson,
    String? uiPrefsJson,
  }) async {
    if (kIsWeb) {
      return const ShelfRecoveryWriteResult(wrote: false, mediaTruncated: false);
    }

    final root = await recoveryRoot();
    final staging = Directory('${root.path}$_sep$stagingDirName');
    if (await staging.exists()) {
      await staging.delete(recursive: true);
    }
    await staging.create(recursive: true);
    final mediaDir = Directory('${staging.path}$_sep$mediaDirName');
    await mediaDir.create(recursive: true);

    final snapshotJson = CollectionSnapshotCodec.encode(snapshot);
    final memory =
        memoryJson ?? await CollectionMemoryStore.instance.encodeJson();
    final uiPrefs =
        uiPrefsJson ??
        CollectionShelfUiPrefsCodec.encode(
          await CollectionShelfUiPrefsStorage.load(),
        );

    final baseBytes =
        utf8.encode(snapshotJson).length +
        utf8.encode(memory).length +
        utf8.encode(uiPrefs).length;

    // Reserve room for a conservative manifest size so total pack ≤ maxBytes.
    const manifestReserve = 512;
    var remaining = maxBytes - baseBytes - manifestReserve;
    if (remaining < 0) remaining = 0;

    final entries = await ShelfMediaVault.entriesByRecentAccess();
    final includedIds = <String>[];
    var truncated = false;
    var skippedMissingThumb = 0;

    for (final entry in entries) {
      final thumbPath = entry.thumbPath;
      if (thumbPath == null || thumbPath.isEmpty) {
        skippedMissingThumb++;
        continue;
      }
      final thumb = File(thumbPath);
      if (!await thumb.exists()) {
        skippedMissingThumb++;
        continue;
      }
      final length = await thumb.length();
      if (length > remaining) {
        truncated = true;
        break;
      }
      final dest = File('${mediaDir.path}$_sep${entry.id}.jpg');
      await thumb.copy(dest.path);
      remaining -= length;
      includedIds.add(entry.id);
    }
    // Prefer size-budget truncation over "missing thumb" for the flag.
    if (!truncated &&
        includedIds.length + skippedMissingThumb < entries.length &&
        remaining == 0) {
      truncated = true;
    }

    final figureCount = snapshot.shelfSeries.fold<int>(
      0,
      (sum, s) => sum + s.figures.length,
    );
    final createdAt = _nowUtc;
    final manifest = ShelfRecoveryManifest(
      schemaVersion: schemaVersion,
      createdAt: createdAt,
      appVersion: appVersion ?? defaultAppVersion,
      seriesCount: snapshot.shelfSeries.length,
      figureCount: figureCount,
      mediaCount: includedIds.length,
      mediaTruncated: truncated,
      memoryPresent: memory.trim().isNotEmpty,
      uiPrefsPresent: uiPrefs.trim().isNotEmpty,
    );
    final manifestJson = jsonEncode(manifest.toJson());

    await File(
      '${staging.path}$_sep$snapshotFileName',
    ).writeAsString(snapshotJson, flush: true);
    await File(
      '${staging.path}$_sep$memoryFileName',
    ).writeAsString(memory, flush: true);
    await File(
      '${staging.path}$_sep$uiPrefsFileName',
    ).writeAsString(uiPrefs, flush: true);
    await File(
      '${staging.path}$_sep$manifestFileName',
    ).writeAsString(manifestJson, flush: true);

    final hook = testBeforeCommitHook;
    if (hook != null) {
      await hook();
    }

    await _commitStaging(root: root, staging: staging);
    return ShelfRecoveryWriteResult(
      wrote: true,
      mediaTruncated: truncated,
      mediaCount: includedIds.length,
    );
  }

  static Future<void> _commitStaging({
    required Directory root,
    required Directory staging,
  }) async {
    final pack = Directory('${root.path}$_sep$packDirName');
    final old = Directory('${root.path}$_sep$oldDirName');
    if (await old.exists()) {
      await old.delete(recursive: true);
    }
    if (await pack.exists()) {
      await pack.rename(old.path);
    }
    await staging.rename(pack.path);
    if (await old.exists()) {
      await old.delete(recursive: true);
    }
  }

  /// Loads the current pack, or `null` if missing / corrupt / expired / unknown.
  ///
  /// Expired packs are deleted and treated as absent.
  static Future<ShelfRecoveryPackContents?> tryLoad() async {
    if (kIsWeb) return null;
    try {
      final pack = await _packDir();
      if (!await pack.exists()) return null;

      final manifestFile = File('${pack.path}$_sep$manifestFileName');
      if (!await manifestFile.exists()) {
        await _deleteQuietly(pack);
        return null;
      }

      final manifestRaw = await manifestFile.readAsString();
      Map<String, dynamic> manifestMap;
      try {
        final decoded = jsonDecode(manifestRaw);
        if (decoded is! Map) {
          await _deleteQuietly(pack);
          return null;
        }
        manifestMap = Map<String, dynamic>.from(decoded);
      } catch (_) {
        await _deleteQuietly(pack);
        return null;
      }
      final manifest = ShelfRecoveryManifest.tryParse(manifestMap);
      if (manifest == null) {
        await _deleteQuietly(pack);
        return null;
      }
      if (manifest.schemaVersion != schemaVersion) {
        await _deleteQuietly(pack);
        return null;
      }

      final age = _nowUtc.difference(manifest.createdAt);
      if (age >= expiry) {
        await _deleteQuietly(pack);
        return null;
      }

      final snapshotRaw = await File(
        '${pack.path}$_sep$snapshotFileName',
      ).readAsString();
      final snapshot = CollectionSnapshotCodec.tryDecode(snapshotRaw);
      if (snapshot == null) {
        await _deleteQuietly(pack);
        return null;
      }

      final memoryRaw = await File(
        '${pack.path}$_sep$memoryFileName',
      ).readAsString();
      final uiPrefsRaw = await File(
        '${pack.path}$_sep$uiPrefsFileName',
      ).readAsString();

      final mediaDir = Directory('${pack.path}$_sep$mediaDirName');
      final mediaIds = <String>[];
      if (await mediaDir.exists()) {
        await for (final entity in mediaDir.list()) {
          if (entity is! File) continue;
          final name = entity.uri.pathSegments.isEmpty
              ? entity.path.split(_sep).last
              : entity.uri.pathSegments.last;
          if (!name.toLowerCase().endsWith('.jpg')) continue;
          mediaIds.add(name.substring(0, name.length - 4));
        }
      }
      mediaIds.sort();

      return ShelfRecoveryPackContents(
        manifest: manifest,
        snapshot: snapshot,
        snapshotJson: snapshotRaw,
        memoryJson: memoryRaw,
        uiPrefsJson: uiPrefsRaw,
        mediaIds: mediaIds,
        packPath: pack.path,
      );
    } on Object catch (e, st) {
      debugPrint('ShelfRecoveryPack.tryLoad failed: $e\n$st');
      return null;
    }
  }

  static Future<void> _deleteQuietly(Directory dir) async {
    try {
      if (await dir.exists()) await dir.delete(recursive: true);
    } on Object {
      // Best-effort cleanup of corrupt / expired packs.
    }
  }
}

@immutable
class ShelfRecoveryManifest {
  const ShelfRecoveryManifest({
    required this.schemaVersion,
    required this.createdAt,
    required this.appVersion,
    required this.seriesCount,
    required this.figureCount,
    required this.mediaCount,
    required this.mediaTruncated,
    required this.memoryPresent,
    required this.uiPrefsPresent,
  });

  final int schemaVersion;
  final DateTime createdAt;
  final String appVersion;
  final int seriesCount;
  final int figureCount;
  final int mediaCount;
  final bool mediaTruncated;
  final bool memoryPresent;
  final bool uiPrefsPresent;

  Map<String, Object?> toJson() => {
    'schemaVersion': schemaVersion,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'appVersion': appVersion,
    'seriesCount': seriesCount,
    'figureCount': figureCount,
    'mediaCount': mediaCount,
    'mediaTruncated': mediaTruncated,
    'memoryPresent': memoryPresent,
    'uiPrefsPresent': uiPrefsPresent,
  };

  static ShelfRecoveryManifest? tryParse(Map<String, dynamic> json) {
    try {
      final version = json['schemaVersion'];
      if (version is! int) return null;
      final createdRaw = json['createdAt']?.toString();
      if (createdRaw == null || createdRaw.isEmpty) return null;
      final createdAt = DateTime.tryParse(createdRaw)?.toUtc();
      if (createdAt == null) return null;
      return ShelfRecoveryManifest(
        schemaVersion: version,
        createdAt: createdAt,
        appVersion: json['appVersion']?.toString() ?? '',
        seriesCount: (json['seriesCount'] as num?)?.toInt() ?? 0,
        figureCount: (json['figureCount'] as num?)?.toInt() ?? 0,
        mediaCount: (json['mediaCount'] as num?)?.toInt() ?? 0,
        mediaTruncated: json['mediaTruncated'] == true,
        memoryPresent: json['memoryPresent'] != false,
        uiPrefsPresent: json['uiPrefsPresent'] != false,
      );
    } catch (_) {
      return null;
    }
  }
}

@immutable
class ShelfRecoveryWriteResult {
  const ShelfRecoveryWriteResult({
    required this.wrote,
    required this.mediaTruncated,
    this.mediaCount = 0,
  });

  final bool wrote;
  final bool mediaTruncated;
  final int mediaCount;
}

@immutable
class ShelfRecoveryPackContents {
  const ShelfRecoveryPackContents({
    required this.manifest,
    required this.snapshot,
    required this.snapshotJson,
    required this.memoryJson,
    required this.uiPrefsJson,
    required this.mediaIds,
    required this.packPath,
  });

  final ShelfRecoveryManifest manifest;
  final CollectionSnapshot snapshot;
  final String snapshotJson;
  final String memoryJson;
  final String uiPrefsJson;
  final List<String> mediaIds;
  final String packPath;
}
