import 'dart:convert';
import 'dart:io';

import 'package:blindbox_app/core/media/device_local_ref.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

/// App-owned shelf photos (originals + recovery thumbnails).
///
/// Picker cache paths are copied here so uninstall/recovery work can find them.
/// Layout under Application Support:
/// ```
/// shelf_media/
///   originals/<id>.<ext>
///   thumbs/<id>.jpg          // longest edge 512, JPEG q75
///   index.json
/// ```
abstract final class ShelfMediaVault {
  ShelfMediaVault._();

  static const rootFolderName = 'shelf_media';
  static const originalsFolderName = 'originals';
  static const thumbsFolderName = 'thumbs';
  static const indexFileName = 'index.json';

  /// Recovery / Auto Backup thumb budget knobs (used by later recovery PR).
  static const thumbLongestEdge = 512;
  static const thumbJpegQuality = 75;
  static const autoBackupMaxBytes = 20 * 1024 * 1024;

  static const _uuid = Uuid();

  @visibleForTesting
  static Directory? testRootOverride;

  @visibleForTesting
  static void resetForTest({bool clearRootOverride = true}) {
    if (clearRootOverride) {
      testRootOverride = null;
    }
    _rootFuture = null;
    _index = null;
  }

  static Future<Directory>? _rootFuture;
  static _VaultIndex? _index;

  static Future<Directory> _root() {
    if (testRootOverride != null) {
      return Future.value(testRootOverride!);
    }
    return _rootFuture ??= _resolveRoot();
  }

  static Future<Directory> _resolveRoot() async {
    final base = await getApplicationSupportDirectory();
    final root = Directory(
      '${base.path}$_sep$rootFolderName',
    );
    if (!await root.exists()) {
      await root.create(recursive: true);
    }
    return root;
  }

  static String get _sep => Platform.pathSeparator;

  static Future<Directory> _subdir(String name) async {
    final root = await _root();
    final dir = Directory('${root.path}$_sep$name');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// True when [path] lives under this vault's `originals/` directory.
  static Future<bool> isVaultOriginalPath(String path) async {
    final root = await _root();
    final originals = Directory('${root.path}$_sep$originalsFolderName');
    final normalized = DeviceLocalImageRef.normalizeToFilePath(
      path,
    ).replaceAll('\\', '/');
    final prefix = originals.path.replaceAll('\\', '/');
    return normalized == prefix || normalized.startsWith('$prefix/');
  }

  /// Import a picker/cache file into the vault; returns the durable original path.
  ///
  /// Also writes a recovery thumbnail. No-op copy when [sourcePath] is already
  /// a vault original.
  static Future<String?> importFromPath(String sourcePath) async {
    if (kIsWeb) return sourcePath.trim().isEmpty ? null : sourcePath.trim();
    final source = DeviceLocalImageRef.normalizeToFilePath(sourcePath.trim());
    if (source.isEmpty) return null;
    if (await isVaultOriginalPath(source)) {
      await _ensureThumbForExistingOriginal(source);
      return source;
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

    final thumbRel = '$thumbsFolderName/$id.jpg';
    final thumbPath = await _writeThumb(id: id, sourceBytes: bytes);

    final now = DateTime.now().toUtc();
    final index = await _ensureIndex();
    index.upsert(
      id: id,
      originalRelative: '$originalsFolderName/$id$ext',
      thumbRelative: thumbPath == null ? null : thumbRel,
      createdAt: now,
      lastAccessedAt: now,
    );
    await _flushIndex();
    return originalPath;
  }

  /// If [uri] is outside the vault but the file exists, import it; otherwise
  /// return the normalized path (or null when empty).
  static Future<String?> ensureInVault(String? uri) async {
    final raw = uri?.trim();
    if (raw == null || raw.isEmpty) return null;
    if (kIsWeb) return raw;
    final path = DeviceLocalImageRef.normalizeToFilePath(raw);
    if (await isVaultOriginalPath(path)) {
      await _ensureThumbForExistingOriginal(path);
      return path;
    }
    if (!await File(path).exists()) return path;
    return await importFromPath(path) ?? path;
  }

  /// Absolute thumb path for a vault original, if present.
  static Future<String?> thumbPathForOriginal(String originalPath) async {
    final id = await _idForOriginalPath(originalPath);
    if (id == null) return null;
    final thumbs = await _subdir(thumbsFolderName);
    final path = '${thumbs.path}$_sep$id.jpg';
    if (await File(path).exists()) return path;
    return null;
  }

  /// Rewrite snapshot local photo URIs into the vault when source files exist.
  static Future<ShelfMediaMigrationResult> migrateSnapshot(
    CollectionSnapshot snapshot,
  ) async {
    if (kIsWeb) {
      return ShelfMediaMigrationResult(snapshot: snapshot, changed: false);
    }
    var changed = false;
    final nextSeries = <ShelfSeries>[];
    for (final series in snapshot.shelfSeries) {
      final cover = series.customCoverImageUri;
      final nextCover = await ensureInVault(cover);
      if (nextCover != cover) changed = true;

      final nextFigures = <ShelfFigure>[];
      for (final figure in series.figures) {
        final local = figure.localImageUri;
        final nextLocal = await ensureInVault(local);
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

    if (!changed) {
      return ShelfMediaMigrationResult(snapshot: snapshot, changed: false);
    }
    return ShelfMediaMigrationResult(
      snapshot: snapshot.copyWith(shelfSeries: nextSeries),
      changed: true,
    );
  }

  /// Entries newest [lastAccessedAt] first — for recovery package truncation.
  static Future<List<ShelfMediaVaultEntry>> entriesByRecentAccess() async {
    final index = await _ensureIndex();
    final root = await _root();
    final list = index.entries.values.toList()
      ..sort((a, b) => b.lastAccessedAt.compareTo(a.lastAccessedAt));
    return [
      for (final e in list)
        ShelfMediaVaultEntry(
          id: e.id,
          originalPath: _absoluteFromRelative(root, e.originalRelative),
          thumbPath: e.thumbRelative == null
              ? null
              : _absoluteFromRelative(root, e.thumbRelative!),
          createdAt: e.createdAt,
          lastAccessedAt: e.lastAccessedAt,
        ),
    ];
  }

  static String _absoluteFromRelative(Directory root, String relative) {
    final parts = relative.split('/');
    return ([root.path, ...parts]).join(_sep);
  }

  static Future<void> touchAccess(String originalPath) async {
    final id = await _idForOriginalPath(originalPath);
    if (id == null) return;
    final index = await _ensureIndex();
    final entry = index.entries[id];
    if (entry == null) return;
    index.upsert(
      id: id,
      originalRelative: entry.originalRelative,
      thumbRelative: entry.thumbRelative,
      createdAt: entry.createdAt,
      lastAccessedAt: DateTime.now().toUtc(),
    );
    await _flushIndex();
  }

  static String _extensionFor(String sourcePath, List<int> bytes) {
    final dot = sourcePath.lastIndexOf('.');
    if (dot > 0 && dot < sourcePath.length - 1) {
      final ext = sourcePath.substring(dot).toLowerCase();
      if (ext == '.jpg' ||
          ext == '.jpeg' ||
          ext == '.png' ||
          ext == '.webp' ||
          ext == '.heic' ||
          ext == '.heif') {
        return ext == '.jpeg' ? '.jpg' : ext;
      }
    }
    // Default after image_picker JPEG compress.
    if (bytes.length >= 3 &&
        bytes[0] == 0xFF &&
        bytes[1] == 0xD8 &&
        bytes[2] == 0xFF) {
      return '.jpg';
    }
    return '.jpg';
  }

  static Future<String?> _writeThumb({
    required String id,
    required List<int> sourceBytes,
  }) async {
    try {
      final decoded = img.decodeImage(Uint8List.fromList(sourceBytes));
      if (decoded == null) return null;
      final longest = decoded.width > decoded.height
          ? decoded.width
          : decoded.height;
      final img.Image sized;
      if (longest <= thumbLongestEdge) {
        sized = decoded;
      } else if (decoded.width >= decoded.height) {
        sized = img.copyResize(
          decoded,
          width: thumbLongestEdge,
          interpolation: img.Interpolation.average,
        );
      } else {
        sized = img.copyResize(
          decoded,
          height: thumbLongestEdge,
          interpolation: img.Interpolation.average,
        );
      }
      final jpg = img.encodeJpg(sized, quality: thumbJpegQuality);
      final thumbs = await _subdir(thumbsFolderName);
      final path = '${thumbs.path}$_sep$id.jpg';
      await File(path).writeAsBytes(jpg, flush: true);
      return path;
    } on Object catch (e, st) {
      debugPrint('ShelfMediaVault: thumb encode failed: $e\n$st');
      return null;
    }
  }

  static Future<void> _ensureThumbForExistingOriginal(String originalPath) async {
    final existing = await thumbPathForOriginal(originalPath);
    if (existing != null) {
      await touchAccess(originalPath);
      return;
    }
    final id = _parseIdFromOriginalPath(originalPath);
    if (id == null) return;
    final bytes = await File(originalPath).readAsBytes();
    if (bytes.isEmpty) return;
    final thumbRel = '$thumbsFolderName/$id.jpg';
    final thumbPath = await _writeThumb(id: id, sourceBytes: bytes);
    final index = await _ensureIndex();
    final prev = index.entries[id];
    final now = DateTime.now().toUtc();
    final originalRel =
        prev?.originalRelative ??
        '$originalsFolderName/${originalPath.split(Platform.pathSeparator).last}';
    index.upsert(
      id: id,
      originalRelative: originalRel,
      thumbRelative: thumbPath == null ? null : thumbRel,
      createdAt: prev?.createdAt ?? now,
      lastAccessedAt: now,
    );
    await _flushIndex();
  }

  static Future<String?> _idForOriginalPath(String originalPath) async {
    if (!await isVaultOriginalPath(originalPath)) return null;
    return _parseIdFromOriginalPath(originalPath);
  }

  static String? _parseIdFromOriginalPath(String originalPath) {
    final name = originalPath.replaceAll('\\', '/').split('/').last;
    final dot = name.lastIndexOf('.');
    if (dot <= 0) return null;
    final id = name.substring(0, dot);
    if (id.isEmpty) return null;
    return id;
  }

  static Future<_VaultIndex> _ensureIndex() async {
    if (_index != null) return _index!;
    final root = await _root();
    final indexFile = File('${root.path}/$indexFileName');
    if (await indexFile.exists()) {
      try {
        final raw = await indexFile.readAsString();
        _index = _VaultIndex.fromJson(
          jsonDecode(raw) as Map<String, dynamic>,
        );
        return _index!;
      } on Object {
        // Fall through to empty.
      }
    }
    _index = _VaultIndex.empty();
    return _index!;
  }

  static Future<void> _flushIndex() async {
    if (_index == null || !_index!.dirty) return;
    final root = await _root();
    final indexFile = File('${root.path}/$indexFileName');
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
class ShelfMediaVaultEntry {
  const ShelfMediaVaultEntry({
    required this.id,
    required this.originalPath,
    required this.thumbPath,
    required this.createdAt,
    required this.lastAccessedAt,
  });

  final String id;
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
  }) {
    entries[id] = _VaultIndexEntry(
      id: id,
      originalRelative: originalRelative,
      thumbRelative: thumbRelative,
      createdAt: createdAt,
      lastAccessedAt: lastAccessedAt,
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
  });

  final String id;
  final String originalRelative;
  final String? thumbRelative;
  final DateTime createdAt;
  final DateTime lastAccessedAt;

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
    );
  }

  Map<String, dynamic> toJson() => {
    'original': originalRelative,
    if (thumbRelative != null) 'thumb': thumbRelative,
    'createdAt': createdAt.toIso8601String(),
    'lastAccessedAt': lastAccessedAt.toIso8601String(),
  };
}
