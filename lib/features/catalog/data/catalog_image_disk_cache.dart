import 'dart:convert';
import 'dart:io';

import 'package:blindbox_app/features/catalog/catalog_image_resolver.dart';
import 'package:blindbox_app/features/catalog/data/catalog_image_cache_policy.dart';
import 'package:blindbox_app/features/catalog/data/catalog_image_version.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// Persistent on-device cache for catalog images fetched from Firebase Storage.
///
/// Intermediate resilience layer: bounded LRU, TTL-based staleness, background
/// refresh orchestrated by [CatalogImageResolver]. Not used on web.
///
/// Cache identity is [CatalogImageVersion.diskEntryKey]: when `imageVersion`
/// changes under the same `imageKey`, the prior entry is a miss and old files
/// for that `imageKey` are purged on persist.
abstract final class CatalogImageDiskCache {
  CatalogImageDiskCache._();

  static const _rootFolderName = 'catalog_image_cache';
  static const _indexFileName = 'cache_index.json';
  static const _versionStemSeparator = '__v';

  @visibleForTesting
  static Directory? testRootOverride;

  @visibleForTesting
  static http.Client? httpClientOverride;

  @visibleForTesting
  static int? testMaxCacheBytesOverride;

  @visibleForTesting
  static DateTime? testNowOverride;

  @visibleForTesting
  static void resetForTest() {
    testRootOverride = null;
    httpClientOverride = null;
    testMaxCacheBytesOverride = null;
    testNowOverride = null;
    _rootFuture = null;
    _index = null;
  }

  static Future<Directory>? _rootFuture;
  static _CacheIndex? _index;

  static int get _maxCacheBytes =>
      testMaxCacheBytesOverride ?? CatalogImageCachePolicy.maxCacheBytes;

  static DateTime get _now => testNowOverride ?? DateTime.now();

  static String entryKey({
    required CatalogImageKind kind,
    required String imageKey,
    String? imageVersion,
  }) => CatalogImageVersion.diskEntryKey(
    kind: kind,
    imageKey: imageKey,
    imageVersion: imageVersion,
  );

  static Future<Directory> _cacheRoot() {
    if (testRootOverride != null) {
      return Future.value(testRootOverride!);
    }
    return _rootFuture ??= _resolveCacheRoot();
  }

  static Future<Directory> _resolveCacheRoot() async {
    final base = await getApplicationSupportDirectory();
    final root = Directory('${base.path}/$_rootFolderName');
    if (!await root.exists()) {
      await root.create(recursive: true);
    }
    return root;
  }

  static String _subdirName(CatalogImageKind kind) => switch (kind) {
    CatalogImageKind.figure => 'figures',
    CatalogImageKind.series => 'series',
  };

  static String _safeStem(String imageKey) {
    final k = imageKey.trim();
    if (k.isEmpty) return '';
    return k.replaceAll(RegExp(r'[^\w\-.]'), '_');
  }

  /// Filename stem: `imageKey` or `imageKey__v<fileToken(version)>`.
  static String _fileStem(String imageKey, String? imageVersion) {
    final stem = _safeStem(imageKey);
    if (stem.isEmpty) return '';
    final v = CatalogImageVersion.normalize(imageVersion);
    if (v == null) return stem;
    return '$stem$_versionStemSeparator${CatalogImageVersion.fileToken(v)}';
  }

  static Future<Directory> _kindDirectory(CatalogImageKind kind) async {
    final root = await _cacheRoot();
    final dir = Directory('${root.path}/${_subdirName(kind)}');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  static Future<_CacheIndex> _ensureIndex() async {
    if (_index != null) return _index!;
    final root = await _cacheRoot();
    final indexFile = File('${root.path}/$_indexFileName');
    if (await indexFile.exists()) {
      try {
        final raw = await indexFile.readAsString();
        _index = _CacheIndex.fromJson(jsonDecode(raw) as Map<String, dynamic>);
        await _index!.pruneMissingFiles();
        return _index!;
      } on Object {
        // Fall through to rebuild.
      }
    }
    _index = await _rebuildIndexFromDisk(root);
    await _index!.save(indexFile);
    return _index!;
  }

  static Future<_CacheIndex> _rebuildIndexFromDisk(Directory root) async {
    final index = _CacheIndex.empty();
    for (final kind in CatalogImageKind.values) {
      final dir = Directory('${root.path}/${_subdirName(kind)}');
      if (!await dir.exists()) continue;
      await for (final entity in dir.list()) {
        if (entity is! File) continue;
        final name = entity.uri.pathSegments.last;
        final dot = name.lastIndexOf('.');
        if (dot <= 0) continue;
        final stem = name.substring(0, dot);
        final parsed = _parseFileStem(stem);
        if (parsed == null) continue;
        final stat = await entity.stat();
        if (stat.size <= 0) continue;
        final key = entryKey(
          kind: kind,
          imageKey: parsed.imageKey,
          imageVersion: parsed.imageVersion,
        );
        index.upsert(
          key: key,
          path: entity.path,
          sizeBytes: stat.size,
          writtenAt: stat.modified,
          lastAccessedAt: stat.modified,
          imageKey: parsed.imageKey,
          imageVersion: parsed.imageVersion,
        );
      }
    }
    return index;
  }

  static ({String imageKey, String? imageVersion})? _parseFileStem(String stem) {
    final sep = stem.indexOf(_versionStemSeparator);
    if (sep < 0) {
      if (stem.isEmpty) return null;
      return (imageKey: stem, imageVersion: null);
    }
    final imageKey = stem.substring(0, sep);
    if (imageKey.isEmpty) return null;
    final token = stem.substring(sep + _versionStemSeparator.length);
    final version = CatalogImageVersion.parseFileToken(token);
    return (imageKey: imageKey, imageVersion: version);
  }

  static bool _isStale(DateTime writtenAt) =>
      _now.difference(writtenAt) > CatalogImageCachePolicy.maxEntryAge;

  /// Lookup with freshness metadata. Touches LRU access time on hit.
  static Future<CatalogDiskCacheHit?> lookup({
    required CatalogImageKind kind,
    required String imageKey,
    String? imageVersion,
  }) async {
    if (kIsWeb) return null;
    try {
      final key = entryKey(
        kind: kind,
        imageKey: imageKey,
        imageVersion: imageVersion,
      );
      final index = await _ensureIndex();
      final entry = index.entries[key];
      if (entry != null) {
        final file = File(entry.path);
        if (await file.exists() && await file.length() > 0) {
          index.touch(key, at: _now);
          await _flushIndex();
          return CatalogDiskCacheHit(
            localPath: entry.path,
            isStale: _isStale(entry.writtenAt),
            writtenAt: entry.writtenAt,
          );
        }
        index.remove(key);
        await _flushIndex();
      }

      final stem = _fileStem(imageKey, imageVersion);
      if (stem.isEmpty) return null;
      final dir = await _kindDirectory(kind);
      for (final ext in CatalogImageResolver.assetExtensions) {
        final file = File('${dir.path}/$stem$ext');
        if (!await file.exists()) continue;
        final len = await file.length();
        if (len <= 0) continue;
        final stat = await file.stat();
        final writtenAt = stat.modified;
        index.upsert(
          key: key,
          path: file.path,
          sizeBytes: len,
          writtenAt: writtenAt,
          lastAccessedAt: _now,
          imageKey: imageKey.trim(),
          imageVersion: CatalogImageVersion.normalize(imageVersion),
        );
        await _evictIfNeeded();
        await _flushIndex();
        return CatalogDiskCacheHit(
          localPath: file.path,
          isStale: _isStale(writtenAt),
          writtenAt: writtenAt,
        );
      }
      return null;
    } on Object {
      return null;
    }
  }

  /// Path-only lookup — prefer [lookup] when staleness matters.
  static Future<String?> lookupLocalPath({
    required CatalogImageKind kind,
    required String imageKey,
    String? imageVersion,
  }) async {
    final hit = await lookup(
      kind: kind,
      imageKey: imageKey,
      imageVersion: imageVersion,
    );
    return hit?.localPath;
  }

  /// Whether a background Storage refresh may be attempted for a stale entry.
  static Future<bool> shouldAttemptBackgroundRefresh({
    required CatalogImageKind kind,
    required String imageKey,
    String? imageVersion,
  }) async {
    if (kIsWeb) return false;
    try {
      final key = entryKey(
        kind: kind,
        imageKey: imageKey,
        imageVersion: imageVersion,
      );
      final index = await _ensureIndex();
      final entry = index.entries[key];
      if (entry == null) return false;
      if (!_isStale(entry.writtenAt)) return false;
      final last = entry.lastRefreshAttemptAt;
      if (last == null) return true;
      return _now.difference(last) > CatalogImageCachePolicy.refreshCooldown;
    } on Object {
      return false;
    }
  }

  /// Records a refresh attempt immediately to dedupe in-flight storms.
  static Future<void> markRefreshAttempted({
    required CatalogImageKind kind,
    required String imageKey,
    String? imageVersion,
  }) async {
    if (kIsWeb) return;
    try {
      final key = entryKey(
        kind: kind,
        imageKey: imageKey,
        imageVersion: imageVersion,
      );
      final index = await _ensureIndex();
      index.markRefreshAttempt(key, at: _now);
      await _flushIndex();
    } on Object {
      // Best-effort.
    }
  }

  /// Deletes index entries + files for [imageKey] under [kind], except [keepKey].
  static Future<void> _purgeOtherVersions({
    required CatalogImageKind kind,
    required String imageKey,
    required String keepKey,
  }) async {
    final index = await _ensureIndex();
    final victims = <String>[];
    for (final key in index.entries.keys) {
      if (key == keepKey) continue;
      if (CatalogImageVersion.entryKeyMatchesImageKey(
        entryKey: key,
        kind: kind,
        imageKey: imageKey,
      )) {
        victims.add(key);
      }
    }
    for (final key in victims) {
      final entry = index.entries[key];
      if (entry != null) {
        final file = File(entry.path);
        if (await file.exists()) {
          await file.delete();
        }
      }
      index.remove(key);
    }

    // Also scrub orphan files for this imageKey (index miss / legacy names).
    final safe = _safeStem(imageKey);
    if (safe.isEmpty) {
      await _flushIndex();
      return;
    }
    final dir = await _kindDirectory(kind);
    await for (final entity in dir.list()) {
      if (entity is! File) continue;
      final name = entity.uri.pathSegments.last;
      final dot = name.lastIndexOf('.');
      if (dot <= 0) continue;
      final stem = name.substring(0, dot);
      final parsed = _parseFileStem(stem);
      if (parsed == null) continue;
      if (parsed.imageKey != safe && parsed.imageKey != imageKey.trim()) {
        continue;
      }
      final key = entryKey(
        kind: kind,
        imageKey: imageKey,
        imageVersion: parsed.imageVersion,
      );
      if (key == keepKey) continue;
      if (await entity.exists()) {
        await entity.delete();
      }
      index.remove(key);
    }
    await _flushIndex();
  }

  static Future<void> _registerEntry({
    required CatalogImageKind kind,
    required String imageKey,
    String? imageVersion,
    required String path,
    required int sizeBytes,
  }) async {
    final index = await _ensureIndex();
    final key = entryKey(
      kind: kind,
      imageKey: imageKey,
      imageVersion: imageVersion,
    );
    index.upsert(
      key: key,
      path: path,
      sizeBytes: sizeBytes,
      writtenAt: _now,
      lastAccessedAt: _now,
      imageKey: imageKey.trim(),
      imageVersion: CatalogImageVersion.normalize(imageVersion),
    );
    await _purgeOtherVersions(
      kind: kind,
      imageKey: imageKey,
      keepKey: key,
    );
    await _evictIfNeeded();
    await _flushIndex();
  }

  static Future<void> _evictIfNeeded() async {
    final index = await _ensureIndex();
    var total = index.totalBytes;
    if (total <= _maxCacheBytes) return;

    final victims = index.entriesByOldestAccess();
    for (final entry in victims) {
      if (total <= _maxCacheBytes) break;
      final file = File(entry.value.path);
      if (await file.exists()) {
        await file.delete();
      }
      index.remove(entry.key);
      total -= entry.value.sizeBytes;
    }
    await _flushIndex();
  }

  static Future<void> _flushIndex() async {
    if (_index == null || !_index!.dirty) return;
    final root = await _cacheRoot();
    final indexFile = File('${root.path}/$_indexFileName');
    await _index!.save(indexFile);
  }

  /// Downloads [downloadUrl] and stores bytes under [imageKey] (+ optional version).
  static Future<String?> persistFromUrl({
    required CatalogImageKind kind,
    required String imageKey,
    required String downloadUrl,
    required String extension,
    String? imageVersion,
  }) async {
    if (kIsWeb) return null;
    final stem = _fileStem(imageKey, imageVersion);
    if (stem.isEmpty) return null;
    final ext = extension.startsWith('.') ? extension : '.$extension';
    final dir = await _kindDirectory(kind);
    final file = File('${dir.path}/$stem$ext');
    try {
      final client = httpClientOverride ?? http.Client();
      final busted = CatalogImageVersion.appendQueryParam(
        downloadUrl,
        imageVersion,
      );
      final response = await client
          .get(Uri.parse(busted))
          .timeout(CatalogImageResolver.storageUrlTimeout);
      if (response.statusCode != 200 || response.bodyBytes.isEmpty) {
        return null;
      }
      await file.writeAsBytes(response.bodyBytes, flush: true);
      await _registerEntry(
        kind: kind,
        imageKey: imageKey,
        imageVersion: imageVersion,
        path: file.path,
        sizeBytes: response.bodyBytes.length,
      );
      return file.path;
    } on Object {
      return null;
    }
  }

  /// Writes [bytes] directly — used by tests and optional callers.
  @visibleForTesting
  static Future<String?> persistBytes({
    required CatalogImageKind kind,
    required String imageKey,
    required String extension,
    required List<int> bytes,
    DateTime? writtenAt,
    String? imageVersion,
  }) async {
    if (kIsWeb) return null;
    if (bytes.isEmpty) return null;
    final stem = _fileStem(imageKey, imageVersion);
    if (stem.isEmpty) return null;
    final ext = extension.startsWith('.') ? extension : '.$extension';
    final dir = await _kindDirectory(kind);
    final file = File('${dir.path}/$stem$ext');
    await file.writeAsBytes(bytes, flush: true);
    final index = await _ensureIndex();
    final key = entryKey(
      kind: kind,
      imageKey: imageKey,
      imageVersion: imageVersion,
    );
    final at = writtenAt ?? _now;
    index.upsert(
      key: key,
      path: file.path,
      sizeBytes: bytes.length,
      writtenAt: at,
      lastAccessedAt: at,
      imageKey: imageKey.trim(),
      imageVersion: CatalogImageVersion.normalize(imageVersion),
    );
    await _purgeOtherVersions(
      kind: kind,
      imageKey: imageKey,
      keepKey: key,
    );
    await _evictIfNeeded();
    await _flushIndex();
    return file.path;
  }

  @visibleForTesting
  static Future<int> totalCacheBytes() async {
    final index = await _ensureIndex();
    return index.totalBytes;
  }

  @visibleForTesting
  static Future<int> entryCount() async {
    final index = await _ensureIndex();
    return index.entries.length;
  }

  @visibleForTesting
  static Future<List<String>> entryKeysForTest() async {
    final index = await _ensureIndex();
    return index.entries.keys.toList()..sort();
  }
}

final class _CacheEntry {
  _CacheEntry({
    required this.path,
    required this.sizeBytes,
    required this.writtenAt,
    required this.lastAccessedAt,
    this.lastRefreshAttemptAt,
    this.imageKey,
    this.imageVersion,
  });

  final String path;
  final int sizeBytes;
  final DateTime writtenAt;
  DateTime lastAccessedAt;
  DateTime? lastRefreshAttemptAt;
  final String? imageKey;
  final String? imageVersion;

  Map<String, dynamic> toJson() => {
    'path': path,
    'sizeBytes': sizeBytes,
    'writtenAt': writtenAt.toIso8601String(),
    'lastAccessedAt': lastAccessedAt.toIso8601String(),
    if (lastRefreshAttemptAt != null)
      'lastRefreshAttemptAt': lastRefreshAttemptAt!.toIso8601String(),
    if (imageKey != null) 'imageKey': imageKey,
    if (imageVersion != null) 'imageVersion': imageVersion,
  };

  static _CacheEntry fromJson(Map<String, dynamic> json) => _CacheEntry(
    path: json['path'] as String,
    sizeBytes: json['sizeBytes'] as int,
    writtenAt: DateTime.parse(json['writtenAt'] as String),
    lastAccessedAt: DateTime.parse(json['lastAccessedAt'] as String),
    lastRefreshAttemptAt: json['lastRefreshAttemptAt'] == null
        ? null
        : DateTime.parse(json['lastRefreshAttemptAt'] as String),
    imageKey: json['imageKey'] as String?,
    imageVersion: json['imageVersion'] as String?,
  );
}

final class _CacheIndex {
  _CacheIndex(this.entries);

  factory _CacheIndex.empty() => _CacheIndex({});

  final Map<String, _CacheEntry> entries;
  bool dirty = false;

  int get totalBytes =>
      entries.values.fold<int>(0, (sum, e) => sum + e.sizeBytes);

  void upsert({
    required String key,
    required String path,
    required int sizeBytes,
    required DateTime writtenAt,
    required DateTime lastAccessedAt,
    String? imageKey,
    String? imageVersion,
  }) {
    final existing = entries[key];
    entries[key] = _CacheEntry(
      path: path,
      sizeBytes: sizeBytes,
      writtenAt: writtenAt,
      lastAccessedAt: lastAccessedAt,
      lastRefreshAttemptAt: existing?.lastRefreshAttemptAt,
      imageKey: imageKey ?? existing?.imageKey,
      imageVersion: imageVersion ?? existing?.imageVersion,
    );
    dirty = true;
  }

  void touch(String key, {required DateTime at}) {
    final entry = entries[key];
    if (entry == null) return;
    entry.lastAccessedAt = at;
    dirty = true;
  }

  void markRefreshAttempt(String key, {required DateTime at}) {
    final entry = entries[key];
    if (entry == null) return;
    entry.lastRefreshAttemptAt = at;
    dirty = true;
  }

  void remove(String key) {
    if (entries.remove(key) != null) dirty = true;
  }

  Iterable<MapEntry<String, _CacheEntry>> entriesByOldestAccess() {
    final list = entries.entries.toList()
      ..sort(
        (a, b) => a.value.lastAccessedAt.compareTo(b.value.lastAccessedAt),
      );
    return list;
  }

  Future<void> pruneMissingFiles() async {
    final staleKeys = <String>[];
    for (final e in entries.entries) {
      if (!await File(e.value.path).exists()) {
        staleKeys.add(e.key);
      }
    }
    for (final k in staleKeys) {
      entries.remove(k);
    }
    if (staleKeys.isNotEmpty) dirty = true;
  }

  Future<void> save(File indexFile) async {
    final payload = jsonEncode({
      'version': 2,
      'entries': entries.map((k, v) => MapEntry(k, v.toJson())),
    });
    await indexFile.writeAsString(payload, flush: true);
    dirty = false;
  }

  static _CacheIndex fromJson(Map<String, dynamic> json) {
    final raw = json['entries'] as Map<String, dynamic>? ?? {};
    final map = <String, _CacheEntry>{};
    for (final e in raw.entries) {
      map[e.key] = _CacheEntry.fromJson(e.value as Map<String, dynamic>);
    }
    return _CacheIndex(map);
  }
}
