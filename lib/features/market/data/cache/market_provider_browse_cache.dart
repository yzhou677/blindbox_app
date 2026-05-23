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

  final Map<MarketProviderId, CachedBrowseBatch> _memory = {};

  static String _prefsKey(MarketProviderId id) => 'market_browse_cache_${id.wireName}_v1';

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
