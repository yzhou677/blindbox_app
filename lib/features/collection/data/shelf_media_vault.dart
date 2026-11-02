import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data' show Uint8List;

import 'package:blindbox_app/core/media/device_local_ref.dart';
import 'package:blindbox_app/features/collection/bootstrap/collection_recovery_gate.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:flutter/foundation.dart'
    show debugPrint, immutable, kIsWeb, visibleForTesting;
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

/// Top-level for [Isolate.run] — keep out of [ShelfMediaVault] closures.
Uint8List? encodeShelfMediaThumbJpg({
  required List<int> sourceBytes,
  required int longestEdge,
  required int quality,
}) {
  final decoded = img.decodeImage(Uint8List.fromList(sourceBytes));
  if (decoded == null) return null;
  final longest = decoded.width > decoded.height
      ? decoded.width
      : decoded.height;
  final img.Image sized;
  if (longest <= longestEdge) {
    sized = decoded;
  } else if (decoded.width >= decoded.height) {
    sized = img.copyResize(
      decoded,
      width: longestEdge,
      interpolation: img.Interpolation.average,
    );
  } else {
    sized = img.copyResize(
      decoded,
      height: longestEdge,
      interpolation: img.Interpolation.average,
    );
  }
  return Uint8List.fromList(img.encodeJpg(sized, quality: quality));
}

/// App-owned shelf photos (originals + recovery thumbnails).
///
/// Snapshot fields store **vault-relative** refs:
/// `shelf_media/originals/<id>.<ext>`
/// Absolute picker/cache paths are migrated on import / startup.
///
/// Layout under Application Support:
/// ```
/// shelf_media/
///   originals/<id>.<ext>
///   thumbs/<id>.jpg          // longest edge 512, JPEG q75
///   index.json
/// ```
///
/// [lastAccessedAt] updates only on user pick/replace ([importFromPath]), not on
/// migrate, display, or thumb backfill.
abstract final class ShelfMediaVault {
  ShelfMediaVault._();

  static const rootFolderName = 'shelf_media';
  static const originalsFolderName = 'originals';
  static const thumbsFolderName = 'thumbs';
  static const indexFileName = 'index.json';

  /// Snapshot / codec prefix (relative to Application Support).
  static const refPrefix = 'shelf_media/';
  static const originalsRefPrefix = 'shelf_media/originals/';

  /// Recovery / Auto Backup thumb budget knobs (used by later recovery PR).
  static const thumbLongestEdge = 512;
  static const thumbJpegQuality = 75;
  static const autoBackupMaxBytes = 20 * 1024 * 1024;

  /// Unreferenced vault media younger than this is kept (pick-before-save race).
  static const gcGracePeriod = Duration(hours: 24);

  static const _uuid = Uuid();

  /// Fake Application Support root for tests (vault lives at `<this>/shelf_media`).
  @visibleForTesting
  static Directory? testSupportOverride;

  /// Application Support path (parent of [rootFolderName]).
  static String? _cachedSupportPath;

  @visibleForTesting
  static void resetForTest({bool clearSupportOverride = true}) {
    if (clearSupportOverride) {
      testSupportOverride = null;
    }
    _rootFuture = null;
    _index = null;
    _cachedSupportPath = null;
    _indexOpChain = Future<void>.value();
  }

  static Future<Directory>? _rootFuture;
  static _VaultIndex? _index;

  /// Serializes index writers ([importFromPath] / migrate / GC).
  static Future<void> _indexOpChain = Future<void>.value();

  static Future<T> _runExclusiveIndexOp<T>(Future<T> Function() op) {
    final gate = Completer<void>();
    final previous = _indexOpChain;
    _indexOpChain = gate.future;
    return previous.then((_) async {
      try {
        return await op();
      } finally {
        gate.complete();
      }
    });
  }

  static String get _sep => Platform.pathSeparator;

  /// Resolves Application Support / test support root and creates vault dirs.
  static Future<void> ensureReady() async {
    if (kIsWeb) return;
    await _root();
    await _subdir(originalsFolderName);
    await _subdir(thumbsFolderName);
    await _ensureIndex();
  }

  static Future<Directory> _root() {
    return _rootFuture ??= _resolveRoot();
  }

  static Future<Directory> _resolveRoot() async {
    final base = testSupportOverride ?? await getApplicationSupportDirectory();
    _cachedSupportPath = base.path;
    final root = Directory('${base.path}$_sep$rootFolderName');
    if (!await root.exists()) {
      await root.create(recursive: true);
    }
    return root;
  }

  static Future<Directory> _subdir(String name) async {
    final root = await _root();
    final dir = Directory('${root.path}$_sep$name');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// True when [ref] is a vault-relative snapshot reference.
  static bool isVaultRef(String? ref) {
    final r = ref?.trim() ?? '';
    return r.startsWith(originalsRefPrefix);
  }

  /// Sync resolve for UI. Call [ensureReady] during app startup first.
  ///
  /// - Vault relative → absolute under Application Support
  /// - Absolute / `file:` legacy → normalized file path
  static String? resolveToFilePathSync(String? ref) {
    final raw = ref?.trim();
    if (raw == null || raw.isEmpty) return null;
    if (raw.startsWith(refPrefix)) {
      final support = _cachedSupportPath;
      if (support == null) return null;
      final parts = raw.split('/');
      return ([support, ...parts]).join(_sep);
    }
    if (DeviceLocalImageRef.looksLikeDevicePath(raw)) {
      return DeviceLocalImageRef.normalizeToFilePath(raw);
    }
    return null;
  }

  /// Media id from a vault relative ref or absolute originals path.
  static String? idFromRef(String? ref) {
    final raw = ref?.trim();
    if (raw == null || raw.isEmpty) return null;
    if (isVaultRef(raw)) {
      final name = raw.substring(originalsRefPrefix.length);
      final dot = name.lastIndexOf('.');
      if (dot <= 0) return null;
      return name.substring(0, dot);
    }
    final normalized = DeviceLocalImageRef.normalizeToFilePath(
      raw,
    ).replaceAll('\\', '/');
    final marker = '/$rootFolderName/$originalsFolderName/';
    final idx = normalized.lastIndexOf(marker);
    if (idx < 0) return null;
    final name = normalized.substring(idx + marker.length);
    final dot = name.lastIndexOf('.');
    if (dot <= 0) return null;
    return name.substring(0, dot);
  }

  static String _vaultRefFor({required String id, required String ext}) =>
      '$originalsRefPrefix$id$ext';

  /// Import a picker/cache file; returns a vault-relative ref.
  ///
  /// Updates [lastAccessedAt] (user pick / replace). Already-vault absolute or
  /// relative inputs are normalized to a relative ref without bumping access.
  static Future<String?> importFromPath(String sourcePath) async {
    if (kIsWeb) return sourcePath.trim().isEmpty ? null : sourcePath.trim();
    final trimmed = sourcePath.trim();
    if (trimmed.isEmpty) return null;
    return _runExclusiveIndexOp(() => _importFromPathLocked(trimmed));
  }

  static Future<String?> _importFromPathLocked(String trimmed) async {
    await ensureReady();

    if (isVaultRef(trimmed)) {
      final id = idFromRef(trimmed);
      if (id != null) {
        await _ensureThumbIfMissing(id: id, bumpAccess: false);
      }
      await _flushIndex();
      return trimmed;
    }

    final source = DeviceLocalImageRef.normalizeToFilePath(trimmed);
    final asVaultAbs = await _absoluteIfVaultOriginal(source);
    if (asVaultAbs != null) {
      final id = idFromRef(asVaultAbs)!;
      final ext = _extensionFromFileName(asVaultAbs);
      final relative = _vaultRefFor(id: id, ext: ext);
      await _ensureThumbIfMissing(id: id, bumpAccess: false);
      await _flushIndex();
      return relative;
    }

    final file = File(source);
    if (!await file.exists()) return null;
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) return null;

    final id = _uuid.v4().replaceAll('-', '');
    final ext = _extensionFor(source, bytes);
    final originals = await _subdir(originalsFolderName);
    final originalPath = '${originals.path}$_sep$id$ext';
    await File(originalPath).writeAsBytes(bytes, flush: true);

    final thumbOk = await _writeThumbFile(id: id, sourceBytes: bytes);
    final now = DateTime.now().toUtc();
    final index = await _ensureIndex();
    index.upsert(
      id: id,
      originalRelative: '$originalsFolderName/$id$ext',
      thumbRelative: thumbOk ? '$thumbsFolderName/$id.jpg' : null,
      createdAt: now,
      lastAccessedAt: now,
    );
    await _flushIndex();
    return _vaultRefFor(id: id, ext: ext);
  }

  /// Migrate one URI for startup: import external files, rewrite abs→relative.
  ///
  /// Does **not** bump [lastAccessedAt]. Does not flush (caller flushes once).
  static Future<String?> _migrateUriNoTouch(String? uri) async {
    final raw = uri?.trim();
    if (raw == null || raw.isEmpty) return null;
    if (kIsWeb) return raw;

    if (isVaultRef(raw)) {
      final id = idFromRef(raw);
      if (id != null) {
        await _ensureThumbIfMissing(id: id, bumpAccess: false);
      }
      return raw;
    }

    final path = DeviceLocalImageRef.normalizeToFilePath(raw);
    final vaultAbs = await _absoluteIfVaultOriginal(path);
    if (vaultAbs != null) {
      final id = idFromRef(vaultAbs)!;
      final ext = _extensionFromFileName(vaultAbs);
      await _ensureThumbIfMissing(id: id, bumpAccess: false);
      return _vaultRefFor(id: id, ext: ext);
    }

    if (!await File(path).exists()) return raw;

    // External file still on disk — import without treating as "user access"
    // for ordering: still set lastAccessedAt = createdAt once via import.
    // Review asked migrate not to touch existing vault entries; new imports need
    // an index row. Use createdAt=now and lastAccessedAt=now only for NEW ids.
    return _importBytesWithoutReentry(path);
  }

  static Future<String?> _importBytesWithoutReentry(String sourcePath) async {
    final file = File(sourcePath);
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) return sourcePath;

    final id = _uuid.v4().replaceAll('-', '');
    final ext = _extensionFor(sourcePath, bytes);
    final originals = await _subdir(originalsFolderName);
    final originalPath = '${originals.path}$_sep$id$ext';
    await File(originalPath).writeAsBytes(bytes, flush: true);

    final thumbOk = await _writeThumbFile(id: id, sourceBytes: bytes);
    final now = DateTime.now().toUtc();
    final index = await _ensureIndex();
    // New object: timestamps required. Not a "touch" of a pre-existing entry.
    index.upsert(
      id: id,
      originalRelative: '$originalsFolderName/$id$ext',
      thumbRelative: thumbOk ? '$thumbsFolderName/$id.jpg' : null,
      createdAt: now,
      lastAccessedAt: now,
    );
    return _vaultRefFor(id: id, ext: ext);
  }

  /// Rewrite snapshot URIs to vault-relative refs; backfill missing thumbs.
  ///
  /// Flushes the index at most once. Does not bump access on existing vault
  /// media.
  static Future<ShelfMediaMigrationResult> migrateSnapshot(
    CollectionSnapshot snapshot,
  ) async {
    if (kIsWeb) {
      return ShelfMediaMigrationResult(snapshot: snapshot, changed: false);
    }
    return _runExclusiveIndexOp(() => _migrateSnapshotLocked(snapshot));
  }

  static Future<ShelfMediaMigrationResult> _migrateSnapshotLocked(
    CollectionSnapshot snapshot,
  ) async {
    await ensureReady();
    var changed = false;
    final nextSeries = <ShelfSeries>[];
    for (final series in snapshot.shelfSeries) {
      final cover = series.customCoverImageUri;
      final nextCover = await _migrateUriNoTouch(cover);
      if (nextCover != cover) changed = true;

      final nextFigures = <ShelfFigure>[];
      for (final figure in series.figures) {
        final local = figure.localImageUri;
        final nextLocal = await _migrateUriNoTouch(local);
        if (nextLocal != local) changed = true;
        nextFigures.add(
          ShelfFigure(
            id: figure.id,
            seriesId: figure.seriesId,
            name: figure.name,
            imageUrl: figure.imageUrl,
            localImageUri: nextLocal,
            rarity: figure.rarity,
            isSecret: figure.isSecret,
            rarityLabel: figure.rarityLabel,
            imageKey: figure.imageKey,
            taxonomyBrandId: figure.taxonomyBrandId,
            taxonomyIpId: figure.taxonomyIpId,
            catalogFigureTemplateId: figure.catalogFigureTemplateId,
          ),
        );
      }

      nextSeries.add(
        ShelfSeries(
          id: series.id,
          name: series.name,
          brand: series.brand,
          ipName: series.ipName,
          figures: nextFigures,
          shelfAccent: series.shelfAccent,
          notes: series.notes,
          catalogTemplateId: series.catalogTemplateId,
          taxonomyBrandId: series.taxonomyBrandId,
          taxonomyIpId: series.taxonomyIpId,
          imageKey: series.imageKey,
          customCoverImageUri: nextCover,
          releaseDate: series.releaseDate,
        ),
      );
    }

    await _flushIndex();

    if (!changed) {
      return ShelfMediaMigrationResult(snapshot: snapshot, changed: false);
    }
    return ShelfMediaMigrationResult(
      snapshot: snapshot.copyWith(shelfSeries: nextSeries),
      changed: true,
    );
  }

  /// Deletes unreferenced originals/thumbs/index rows older than [gcGracePeriod].
  ///
  /// Fresh imports (pick before snapshot save) stay until the grace window
  /// passes. Disk orphans without an index row use file modified time the same
  /// way.
  static Future<ShelfMediaGcResult> collectGarbage(
    CollectionSnapshot snapshot,
  ) async {
    if (kIsWeb) {
      return const ShelfMediaGcResult(removedIds: []);
    }
    if (CollectionRecoveryGate.blocksBackgroundWrites) {
      return const ShelfMediaGcResult(removedIds: []);
    }
    return _runExclusiveIndexOp(() => _collectGarbageLocked(snapshot));
  }

  /// Installs a recovery-pack thumb as vault media under a stable [id].
  ///
  /// When originals are missing (Auto Backup only ships thumbs), the thumb
  /// bytes are also written as the original and [recoveredFromThumb] is set.
  static Future<String> installRecoveredThumb({
    required String id,
    required List<int> thumbBytes,
  }) async {
    if (kIsWeb) {
      return _vaultRefFor(id: id, ext: '.jpg');
    }
    return _runExclusiveIndexOp(() async {
      await ensureReady();
      final trimmedId = id.trim();
      if (trimmedId.isEmpty || thumbBytes.isEmpty) {
        throw ArgumentError('recover thumb requires id and bytes');
      }
      final originals = await _subdir(originalsFolderName);
      final thumbs = await _subdir(thumbsFolderName);
      final originalPath = '${originals.path}$_sep$trimmedId.jpg';
      final thumbPath = '${thumbs.path}$_sep$trimmedId.jpg';
      final originalFile = File(originalPath);
      final hadOriginal = await originalFile.exists();
      if (!hadOriginal) {
        await originalFile.writeAsBytes(thumbBytes, flush: true);
      }
      await File(thumbPath).writeAsBytes(thumbBytes, flush: true);
      final now = DateTime.now().toUtc();
      final index = await _ensureIndex();
      final existing = index.entries[trimmedId];
      index.upsert(
        id: trimmedId,
        originalRelative: '$originalsFolderName/$trimmedId.jpg',
        thumbRelative: '$thumbsFolderName/$trimmedId.jpg',
        createdAt: existing?.createdAt ?? now,
        lastAccessedAt: existing?.lastAccessedAt ?? now,
        recoveredFromThumb: !hadOriginal || (existing?.recoveredFromThumb ?? false),
      );
      await _flushIndex();
      return _vaultRefFor(id: trimmedId, ext: '.jpg');
    });
  }

  @visibleForTesting
  static Future<bool?> recoveredFromThumbForTest(String vaultRef) async {
    final id = idFromRef(vaultRef);
    if (id == null) return null;
    final index = await _ensureIndex();
    return index.entries[id]?.recoveredFromThumb;
  }

  static Future<ShelfMediaGcResult> _collectGarbageLocked(
    CollectionSnapshot snapshot,
  ) async {
    await ensureReady();
    final referenced = <String>{};
    for (final series in snapshot.shelfSeries) {
      final coverId = idFromRef(series.customCoverImageUri);
      if (coverId != null) referenced.add(coverId);
      for (final figure in series.figures) {
        final figId = idFromRef(figure.localImageUri);
        if (figId != null) referenced.add(figId);
      }
    }

    final now = DateTime.now().toUtc();
    final index = await _ensureIndex();
    final removed = <String>[];
    final staleIds = index.entries.keys
        .where((id) => !referenced.contains(id))
        .toList(growable: false);
    for (final id in staleIds) {
      final entry = index.entries[id];
      if (entry == null) continue;
      if (!_isOlderThanGrace(entry.createdAt, now: now)) continue;
      await _deleteQuietly(
        _absoluteFromVaultRelative(entry.originalRelative),
      );
      if (entry.thumbRelative != null) {
        await _deleteQuietly(
          _absoluteFromVaultRelative(entry.thumbRelative!),
        );
      }
      index.entries.remove(id);
      index.dirty = true;
      removed.add(id);
    }

    // Orphan files on disk not present in the index.
    final originals = await _subdir(originalsFolderName);
    await for (final entity in originals.list()) {
      if (entity is! File) continue;
      final id = _parseIdFromFileName(entity.path);
      if (id == null) continue;
      if (index.entries.containsKey(id) || referenced.contains(id)) continue;
      final modified = (await entity.stat()).modified.toUtc();
      if (!_isOlderThanGrace(modified, now: now)) continue;
      await _deleteQuietly(entity.path);
      final thumb = await _thumbAbsForId(id);
      await _deleteQuietly(thumb);
      removed.add(id);
    }

    await _flushIndex();
    return ShelfMediaGcResult(removedIds: removed);
  }

  static bool _isOlderThanGrace(DateTime stamp, {required DateTime now}) {
    return !now.difference(stamp.toUtc()).isNegative &&
        now.difference(stamp.toUtc()) >= gcGracePeriod;
  }

  /// Entries newest [lastAccessedAt] first — for recovery package truncation.
  static Future<List<ShelfMediaVaultEntry>> entriesByRecentAccess() async {
    await ensureReady();
    final index = await _ensureIndex();
    final list = index.entries.values.toList()
      ..sort((a, b) => b.lastAccessedAt.compareTo(a.lastAccessedAt));
    return [
      for (final e in list)
        ShelfMediaVaultEntry(
          id: e.id,
          vaultRef: _vaultRefFor(
            id: e.id,
            ext: _extensionFromRelative(e.originalRelative),
          ),
          originalPath: _absoluteFromVaultRelative(e.originalRelative),
          thumbPath: e.thumbRelative == null
              ? null
              : _absoluteFromVaultRelative(e.thumbRelative!),
          createdAt: e.createdAt,
          lastAccessedAt: e.lastAccessedAt,
        ),
    ];
  }

  @visibleForTesting
  static Future<DateTime?> lastAccessedAtForTest(String vaultRef) async {
    final id = idFromRef(vaultRef);
    if (id == null) return null;
    final index = await _ensureIndex();
    return index.entries[id]?.lastAccessedAt;
  }

  /// Ages an index row for GC grace-period tests.
  @visibleForTesting
  static Future<void> backdateCreatedAtForTest(
    String vaultRef,
    DateTime createdAt,
  ) async {
    await _runExclusiveIndexOp(() async {
      final id = idFromRef(vaultRef);
      if (id == null) return;
      final index = await _ensureIndex();
      final entry = index.entries[id];
      if (entry == null) return;
      index.upsert(
        id: id,
        originalRelative: entry.originalRelative,
        thumbRelative: entry.thumbRelative,
        createdAt: createdAt.toUtc(),
        lastAccessedAt: entry.lastAccessedAt,
        recoveredFromThumb: entry.recoveredFromThumb,
      );
      await _flushIndex();
    });
  }

  /// Sets [lastAccessedAt] for recovery truncation-order tests.
  @visibleForTesting
  static Future<void> setLastAccessedAtForTest(
    String vaultRef,
    DateTime lastAccessedAt,
  ) async {
    await _runExclusiveIndexOp(() async {
      final id = idFromRef(vaultRef);
      if (id == null) return;
      final index = await _ensureIndex();
      final entry = index.entries[id];
      if (entry == null) return;
      index.upsert(
        id: id,
        originalRelative: entry.originalRelative,
        thumbRelative: entry.thumbRelative,
        createdAt: entry.createdAt,
        lastAccessedAt: lastAccessedAt.toUtc(),
        recoveredFromThumb: entry.recoveredFromThumb,
      );
      await _flushIndex();
    });
  }

  static String _absoluteFromVaultRelative(String relative) {
    // relative like originals/x.jpg under vault root
    final support = _cachedSupportPath;
    if (support == null) {
      throw StateError('ShelfMediaVault.ensureReady() was not called');
    }
    return ([support, rootFolderName, ...relative.split('/')]).join(_sep);
  }

  static Future<String?> _absoluteIfVaultOriginal(String absolutePath) async {
    final normalized = absolutePath.replaceAll('\\', '/');
    final marker = '/$rootFolderName/$originalsFolderName/';
    if (!normalized.contains(marker)) return null;
    final root = await _root();
    final originals = Directory('${root.path}$_sep$originalsFolderName');
    final prefix = originals.path.replaceAll('\\', '/');
    final candidate = normalized;
    if (candidate == prefix || candidate.startsWith('$prefix/')) {
      return absolutePath;
    }
    // Also accept when path uses mixed separators but same location.
    if (File(absolutePath).path.replaceAll('\\', '/').startsWith(prefix)) {
      return absolutePath;
    }
    return null;
  }

  static Future<bool> _ensureThumbIfMissing({
    required String id,
    required bool bumpAccess,
  }) async {
    final index = await _ensureIndex();
    final entry = index.entries[id];
    final thumbAbs = await _thumbAbsForId(id);
    if (await File(thumbAbs).exists()) {
      if (bumpAccess && entry != null) {
        index.upsert(
          id: id,
          originalRelative: entry.originalRelative,
          thumbRelative: entry.thumbRelative ?? '$thumbsFolderName/$id.jpg',
          createdAt: entry.createdAt,
          lastAccessedAt: DateTime.now().toUtc(),
          recoveredFromThumb: entry.recoveredFromThumb,
        );
      }
      return false;
    }

    final originalRel =
        entry?.originalRelative ?? '$originalsFolderName/$id.jpg';
    final originalAbs = _absoluteFromVaultRelative(originalRel);
    if (!await File(originalAbs).exists()) return false;
    final bytes = await File(originalAbs).readAsBytes();
    if (bytes.isEmpty) return false;
    final ok = await _writeThumbFile(id: id, sourceBytes: bytes);
    final now = DateTime.now().toUtc();
    index.upsert(
      id: id,
      originalRelative: originalRel,
      thumbRelative: ok ? '$thumbsFolderName/$id.jpg' : null,
      createdAt: entry?.createdAt ?? now,
      lastAccessedAt: bumpAccess
          ? now
          : (entry?.lastAccessedAt ?? now),
      recoveredFromThumb: entry?.recoveredFromThumb ?? false,
    );
    return true;
  }

  static Future<String> _thumbAbsForId(String id) async {
    final thumbs = await _subdir(thumbsFolderName);
    return '${thumbs.path}$_sep$id.jpg';
  }

  static Future<bool> _writeThumbFile({
    required String id,
    required List<int> sourceBytes,
  }) async {
    try {
      final edge = thumbLongestEdge;
      final quality = thumbJpegQuality;
      final jpg = await Isolate.run(
        () => encodeShelfMediaThumbJpg(
          sourceBytes: sourceBytes,
          longestEdge: edge,
          quality: quality,
        ),
      );
      if (jpg == null || jpg.isEmpty) return false;
      final path = await _thumbAbsForId(id);
      await File(path).writeAsBytes(jpg, flush: true);
      return true;
    } on Object catch (e, st) {
      debugPrint('ShelfMediaVault: thumb encode failed: $e\n$st');
      return false;
    }
  }

  static String _extensionFor(String sourcePath, List<int> bytes) {
    final fromName = _extensionFromFileName(sourcePath);
    if (fromName != '.bin') return fromName;
    if (bytes.length >= 3 &&
        bytes[0] == 0xFF &&
        bytes[1] == 0xD8 &&
        bytes[2] == 0xFF) {
      return '.jpg';
    }
    return '.jpg';
  }

  static String _extensionFromFileName(String path) {
    final name = path.replaceAll('\\', '/').split('/').last;
    final dot = name.lastIndexOf('.');
    if (dot <= 0) return '.bin';
    final ext = name.substring(dot).toLowerCase();
    if (ext == '.jpeg') return '.jpg';
    if (ext == '.jpg' ||
        ext == '.png' ||
        ext == '.webp' ||
        ext == '.heic' ||
        ext == '.heif') {
      return ext;
    }
    return '.bin';
  }

  static String _extensionFromRelative(String relative) {
    return _extensionFromFileName(relative);
  }

  static String? _parseIdFromFileName(String path) {
    final name = path.replaceAll('\\', '/').split('/').last;
    final dot = name.lastIndexOf('.');
    if (dot <= 0) return null;
    final id = name.substring(0, dot);
    return id.isEmpty ? null : id;
  }

  static Future<void> _deleteQuietly(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } on Object {
      // Best-effort GC.
    }
  }

  static Future<_VaultIndex> _ensureIndex() async {
    if (_index != null) return _index!;
    final root = await _root();
    final indexFile = File('${root.path}$_sep$indexFileName');
    if (await indexFile.exists()) {
      try {
        final raw = await indexFile.readAsString();
        _index = _VaultIndex.fromJson(
          jsonDecode(raw) as Map<String, dynamic>,
        );
        return _index!;
      } on Object {
        // Fall through.
      }
    }
    _index = _VaultIndex.empty();
    return _index!;
  }

  static Future<void> _flushIndex() async {
    if (_index == null || !_index!.dirty) return;
    final root = await _root();
    final indexFile = File('${root.path}$_sep$indexFileName');
    await indexFile.writeAsString(jsonEncode(_index!.toJson()), flush: true);
    _index!.dirty = false;
  }
}

@immutable
class ShelfMediaMigrationResult {
  const ShelfMediaMigrationResult({
    required this.snapshot,
    required this.changed,
  });

  final CollectionSnapshot snapshot;
  final bool changed;
}

@immutable
class ShelfMediaGcResult {
  const ShelfMediaGcResult({required this.removedIds});

  final List<String> removedIds;
}

@immutable
class ShelfMediaVaultEntry {
  const ShelfMediaVaultEntry({
    required this.id,
    required this.vaultRef,
    required this.originalPath,
    required this.thumbPath,
    required this.createdAt,
    required this.lastAccessedAt,
  });

  final String id;
  final String vaultRef;
  final String originalPath;
  final String? thumbPath;
  final DateTime createdAt;
  final DateTime lastAccessedAt;
}

class _VaultIndex {
  _VaultIndex(this.entries);

  factory _VaultIndex.empty() => _VaultIndex({});

  factory _VaultIndex.fromJson(Map<String, dynamic> json) {
    final raw = json['entries'];
    final map = <String, _VaultIndexEntry>{};
    if (raw is Map) {
      for (final e in raw.entries) {
        final id = e.key.toString();
        final value = e.value;
        if (value is! Map) continue;
        final entry = _VaultIndexEntry.fromJson(
          id,
          Map<String, dynamic>.from(value),
        );
        if (entry != null) map[id] = entry;
      }
    }
    return _VaultIndex(map);
  }

  final Map<String, _VaultIndexEntry> entries;
  bool dirty = false;

  void upsert({
    required String id,
    required String originalRelative,
    required String? thumbRelative,
    required DateTime createdAt,
    required DateTime lastAccessedAt,
    bool recoveredFromThumb = false,
  }) {
    entries[id] = _VaultIndexEntry(
      id: id,
      originalRelative: originalRelative,
      thumbRelative: thumbRelative,
      createdAt: createdAt,
      lastAccessedAt: lastAccessedAt,
      recoveredFromThumb: recoveredFromThumb,
    );
    dirty = true;
  }

  Map<String, dynamic> toJson() => {
    'entries': {
      for (final e in entries.entries) e.key: e.value.toJson(),
    },
  };
}

class _VaultIndexEntry {
  const _VaultIndexEntry({
    required this.id,
    required this.originalRelative,
    required this.thumbRelative,
    required this.createdAt,
    required this.lastAccessedAt,
    this.recoveredFromThumb = false,
  });

  final String id;
  final String originalRelative;
  final String? thumbRelative;
  final DateTime createdAt;
  final DateTime lastAccessedAt;
  final bool recoveredFromThumb;

  static _VaultIndexEntry? fromJson(String id, Map<String, dynamic> json) {
    final original = json['original']?.toString();
    if (original == null || original.isEmpty) return null;
    DateTime parse(String? raw, DateTime fallback) {
      if (raw == null || raw.isEmpty) return fallback;
      return DateTime.tryParse(raw)?.toUtc() ?? fallback;
    }

    final now = DateTime.now().toUtc();
    return _VaultIndexEntry(
      id: id,
      originalRelative: original,
      thumbRelative: json['thumb']?.toString(),
      createdAt: parse(json['createdAt']?.toString(), now),
      lastAccessedAt: parse(json['lastAccessedAt']?.toString(), now),
      recoveredFromThumb: json['recoveredFromThumb'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
    'original': originalRelative,
    if (thumbRelative != null) 'thumb': thumbRelative,
    'createdAt': createdAt.toIso8601String(),
    'lastAccessedAt': lastAccessedAt.toIso8601String(),
    if (recoveredFromThumb) 'recoveredFromThumb': true,
  };
}
