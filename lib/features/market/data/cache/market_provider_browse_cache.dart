import 'dart:convert';

import 'package:blindbox_app/features/market/data/sandbox/market_sandbox_config.dart';
import 'package:blindbox_app/features/market/domain/market_provider_id.dart';
import 'package:blindbox_app/models/collectible.dart';
import 'package:blindbox_app/models/market_listing.dart';
import 'package:shared_preferences/shared_preferences.dart';

final class CachedBrowseBatch {
  const CachedBrowseBatch({
    required this.fetchedAt,
    required this.listings,
    this.wireJson,
    this.nextCursor,
    this.hasMore = false,
  });

  final DateTime fetchedAt;
  final List<MarketListing> listings;
  final String? wireJson;
  final String? nextCursor;
  final bool hasMore;

  bool isFresh({Duration? ttl}) {
    final maxAge = ttl ?? MarketSandboxConfig.cacheTtl;
    return DateTime.now().difference(fetchedAt) <= maxAge;
  }

  bool isDiskStaleAcceptable({Duration? ttl}) {
    final maxAge = ttl ?? MarketSandboxConfig.diskStaleTtl;
    return DateTime.now().difference(fetchedAt) <= maxAge;
  }
}

/// Per-provider browse cache — in-memory with optional disk persistence for dev.
final class MarketProviderBrowseCache {
  MarketProviderBrowseCache._();

  static final MarketProviderBrowseCache instance = MarketProviderBrowseCache._();

  // Maximum number of distinct query-keyed entries kept in memory and on disk.
  // Prevents unbounded growth when users explore many brand/IP filter combos.
  static const _maxQueryEntries = 10;

  final Map<MarketProviderId, CachedBrowseBatch> _memory = {};

  // LinkedHashMap (default in Dart) preserves insertion order → oldest first.
  // FIFO eviction: when at capacity, _memoryByQuery.keys.first is the oldest.
  final Map<String, CachedBrowseBatch> _memoryByQuery = {};

  static String _queryKey(MarketProviderId id, String signature) =>
      '${id.wireName}|$signature';

  static String _prefsKey(MarketProviderId id) => 'market_browse_cache_${id.wireName}_v1';

  static String _prefsKeyForQuery(MarketProviderId id, String signature) =>
      'market_browse_cache_${id.wireName}_${signature.hashCode.abs()}_v2';

  // Prefs key that stores an ordered list of active disk query-cache keys for
  // FIFO eviction.  Each element is a disk prefs key string.
  static const _diskQueryIndexKey = 'market_browse_cache_query_index_v1';

  /// Evicts the oldest in-memory query entry when at capacity.
  void _evictMemoryIfNeeded(String incomingKey) {
    // If already present the entry will just be overwritten — no eviction.
    if (_memoryByQuery.containsKey(incomingKey)) return;
    while (_memoryByQuery.length >= _maxQueryEntries) {
      _memoryByQuery.remove(_memoryByQuery.keys.first);
    }
  }

  /// Evicts the oldest disk query entry when at capacity and registers the new key.
  Future<void> _evictDiskIfNeeded(
    SharedPreferences prefs,
    String newDiskKey,
  ) async {
    final index = List<String>.from(
      prefs.getStringList(_diskQueryIndexKey) ?? const [],
    );
    if (index.contains(newDiskKey)) return; // already tracked
    while (index.length >= _maxQueryEntries) {
      final evicted = index.removeAt(0);
      await prefs.remove(evicted);
    }
    index.add(newDiskKey);
    await prefs.setStringList(_diskQueryIndexKey, index);
  }

  /// Removes [diskKey] from the on-disk eviction index (called on [clearQuery]).
  Future<void> _removeDiskIndex(SharedPreferences prefs, String diskKey) async {
    final index = List<String>.from(
      prefs.getStringList(_diskQueryIndexKey) ?? const [],
    );
    if (index.remove(diskKey)) {
      await prefs.setStringList(_diskQueryIndexKey, index);
    }
  }

  List<MarketListing>? readStale(
    MarketProviderId id, {
    Duration? ttl,
    bool allowExpired = true,
  }) {
    final batch = _memory[id];
    if (batch == null) return null;
    if (!allowExpired && !batch.isFresh(ttl: ttl)) return null;
    return batch.listings;
  }

  Future<List<MarketListing>?> readStaleFromDisk(MarketProviderId id) async {
    final mem = readStale(id);
    if (mem != null) return mem;

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey(id));
    if (raw == null || raw.isEmpty) return null;

    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final atMs = decoded['fetchedAtMs'] as int? ?? 0;
      final wireJson = decoded['wireJson'] as String?;
      final listingMaps = decoded['listings'] as List<dynamic>? ?? const [];
      final listings = [
        for (final m in listingMaps)
          if (m is Map<String, dynamic>) _marketListingFromJson(m),
      ];
      final batch = CachedBrowseBatch(
        fetchedAt: DateTime.fromMillisecondsSinceEpoch(atMs),
        listings: listings,
        wireJson: wireJson,
        nextCursor: decoded['nextCursor'] as String?,
        hasMore: decoded['hasMore'] as bool? ?? false,
      );
      _memory[id] = batch;
      return batch.listings;
    } catch (_) {
      return null;
    }
  }

  void writeMemory({
    required MarketProviderId id,
    required List<MarketListing> listings,
    String? wireJson,
    String? nextCursor,
    bool hasMore = false,
  }) {
    _memory[id] = CachedBrowseBatch(
      fetchedAt: DateTime.now(),
      listings: List<MarketListing>.unmodifiable(listings),
      wireJson: wireJson,
      nextCursor: nextCursor,
      hasMore: hasMore,
    );
  }

  Future<void> write({
    required MarketProviderId id,
    required List<MarketListing> listings,
    String? wireJson,
    String? nextCursor,
    bool hasMore = false,
  }) async {
    writeMemory(
      id: id,
      listings: listings,
      wireJson: wireJson,
      nextCursor: nextCursor,
      hasMore: hasMore,
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _prefsKey(id),
      jsonEncode({
        'fetchedAtMs': DateTime.now().millisecondsSinceEpoch,
        'wireJson': wireJson,
        'nextCursor': nextCursor,
        'hasMore': hasMore,
        'listings': [for (final l in listings) _marketListingToJson(l)],
      }),
    );
  }

  CachedBrowseBatch? batchFor(MarketProviderId id) => _memory[id];

  CachedBrowseBatch? batchForQuery(MarketProviderId id, String signature) =>
      _memoryByQuery[_queryKey(id, signature)];

  List<MarketListing>? readStaleForQuery(
    MarketProviderId id,
    String signature, {
    Duration? ttl,
    bool allowExpired = true,
  }) {
    final batch = batchForQuery(id, signature);
    if (batch == null) return null;
    if (!allowExpired && !batch.isFresh(ttl: ttl)) return null;
    return batch.listings;
  }

  Future<List<MarketListing>?> readStaleFromDiskForQuery(
    MarketProviderId id,
    String signature,
  ) async {
    final mem = readStaleForQuery(id, signature);
    if (mem != null) return mem;

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKeyForQuery(id, signature));
    if (raw == null || raw.isEmpty) return null;

    try {
      final batch = _batchFromJson(raw);
      _memoryByQuery[_queryKey(id, signature)] = batch;
      return batch.listings;
    } catch (_) {
      return null;
    }
  }

  Future<void> writeForQuery({
    required MarketProviderId id,
    required String signature,
    required List<MarketListing> listings,
    String? wireJson,
    String? nextCursor,
    bool hasMore = false,
  }) async {
    final batch = CachedBrowseBatch(
      fetchedAt: DateTime.now(),
      listings: List<MarketListing>.unmodifiable(listings),
      wireJson: wireJson,
      nextCursor: nextCursor,
      hasMore: hasMore,
    );
    final memKey = _queryKey(id, signature);
    _evictMemoryIfNeeded(memKey);
    _memoryByQuery[memKey] = batch;

    final diskKey = _prefsKeyForQuery(id, signature);
    final prefs = await SharedPreferences.getInstance();
    await _evictDiskIfNeeded(prefs, diskKey);
    await prefs.setString(diskKey, jsonEncode(_batchToJson(batch)));
  }

  Future<void> appendForQuery({
    required MarketProviderId id,
    required String signature,
    required List<MarketListing> newListings,
    String? nextCursor,
    bool hasMore = false,
  }) async {
    final existing = batchForQuery(id, signature);
    final merged = _dedupeAppend(existing?.listings ?? const [], newListings);
    await writeForQuery(
      id: id,
      signature: signature,
      listings: merged,
      wireJson: existing?.wireJson,
      nextCursor: nextCursor,
      hasMore: hasMore,
    );
  }

  void clearQuery(MarketProviderId id, String signature) {
    _memoryByQuery.remove(_queryKey(id, signature));
    // Best-effort disk index cleanup; fire-and-forget.
    SharedPreferences.getInstance().then((prefs) {
      _removeDiskIndex(prefs, _prefsKeyForQuery(id, signature));
    });
  }

  static Map<String, dynamic> _batchToJson(CachedBrowseBatch batch) => {
        'fetchedAtMs': batch.fetchedAt.millisecondsSinceEpoch,
        'wireJson': batch.wireJson,
        'nextCursor': batch.nextCursor,
        'hasMore': batch.hasMore,
        'listings': [for (final l in batch.listings) _marketListingToJson(l)],
      };

  static CachedBrowseBatch _batchFromJson(String raw) {
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final atMs = decoded['fetchedAtMs'] as int? ?? 0;
    final listingMaps = decoded['listings'] as List<dynamic>? ?? const [];
    final listings = [
      for (final m in listingMaps)
        if (m is Map<String, dynamic>) _marketListingFromJson(m),
    ];
    return CachedBrowseBatch(
      fetchedAt: DateTime.fromMillisecondsSinceEpoch(atMs),
      listings: listings,
      wireJson: decoded['wireJson'] as String?,
      nextCursor: decoded['nextCursor'] as String?,
      hasMore: decoded['hasMore'] as bool? ?? false,
    );
  }

  /// Appends deduped rows and updates continuation metadata.
  Future<void> append({
    required MarketProviderId id,
    required List<MarketListing> newListings,
    String? nextCursor,
    bool hasMore = false,
  }) async {
    final existing = _memory[id];
    final merged = _dedupeAppend(existing?.listings ?? const [], newListings);
    await write(
      id: id,
      listings: merged,
      wireJson: existing?.wireJson,
      nextCursor: nextCursor,
      hasMore: hasMore,
    );
  }

  static List<MarketListing> _dedupeAppend(
    List<MarketListing> base,
    List<MarketListing> incoming,
  ) {
    final seen = <String>{};
    for (final row in base) {
      seen.add('${row.providerId}:${row.providerListingId ?? row.id}');
    }
    final out = List<MarketListing>.from(base);
    for (final row in incoming) {
      final key = '${row.providerId}:${row.providerListingId ?? row.id}';
      if (seen.contains(key)) continue;
      seen.add(key);
      out.add(row);
    }
    return out;
  }

  void clear(MarketProviderId id) {
    _memory.remove(id);
  }

  /// Clears all in-memory query entries.  Intended for use in tests only.
  void clearAllQueryMemory() => _memoryByQuery.clear();

  static Map<String, dynamic> _marketListingToJson(MarketListing l) {
    return {
      'id': l.id,
      'providerId': l.providerId,
      'providerListingId': l.providerListingId,
      'externalListingUrl': l.externalListingUrl,
      'name': l.collectible.name,
      'imageUrl': l.collectible.imageUrl,
      'currentPriceUsd': l.currentPriceUsd,
      'priceChangePercent': l.priceChangePercent,
      'listingCount': l.listingCount,
      'taxonomyBrandId': l.taxonomyBrandId,
      'taxonomyIpId': l.taxonomyIpId,
    };
  }

  static MarketListing _marketListingFromJson(Map<String, dynamic> json) {
    final id = json['id'] as String? ?? '';
    return MarketListing(
      id: id,
      providerId: json['providerId'] as String? ?? MarketProviderId.mercari.wireName,
      providerListingId: json['providerListingId'] as String?,
      externalListingUrl: json['externalListingUrl'] as String?,
      taxonomyBrandId: json['taxonomyBrandId'] as String?,
      taxonomyIpId: json['taxonomyIpId'] as String?,
      collectible: Collectible(
        id: id,
        name: json['name'] as String? ?? '',
        series: '',
        brand: '',
        releaseDate: DateTime.utc(2026),
        imageUrl: json['imageUrl'] as String? ?? '',
      ),
      currentPriceUsd: (json['currentPriceUsd'] as num?)?.toDouble() ?? 0,
      priceChangePercent: (json['priceChangePercent'] as num?)?.toDouble() ?? 0,
      listingCount: (json['listingCount'] as num?)?.toInt() ?? 1,
    );
  }
}
