import 'dart:convert';

import 'package:blindbox_app/features/market/data/chasers/market_chasers_config.dart';
import 'package:blindbox_app/features/market/domain/chasers_heat_entry.dart';
import 'package:blindbox_app/models/collectible.dart';
import 'package:blindbox_app/models/market_listing.dart';
import 'package:shared_preferences/shared_preferences.dart';

final class CachedChasersBatch {
  const CachedChasersBatch({
    required this.fetchedAt,
    required this.entries,
  });

  final DateTime fetchedAt;
  final List<ChasersHeatEntry> entries;

  bool isFresh({Duration? ttl}) {
    final maxAge = ttl ?? MarketChasersConfig.memoryRefreshTtl;
    return DateTime.now().difference(fetchedAt) <= maxAge;
  }

  bool isDiskStaleAcceptable({Duration? ttl}) {
    final maxAge = ttl ?? MarketChasersConfig.diskStaleTtl;
    return DateTime.now().difference(fetchedAt) <= maxAge;
  }
}

/// Chasers rail cache — memory + SharedPreferences (stale-while-revalidate).
final class MarketChasersCache {
  MarketChasersCache._();

  static final MarketChasersCache instance = MarketChasersCache._();

  static const _prefsKey = 'market_chasers_rail_v1';

  CachedChasersBatch? _memory;

  CachedChasersBatch? readMemory({bool allowExpired = true}) {
    final batch = _memory;
    if (batch == null) return null;
    if (!allowExpired && !batch.isFresh()) return null;
    return batch;
  }

  Future<CachedChasersBatch?> readFromDisk() async {
    final mem = readMemory();
    if (mem != null) return mem;

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null || raw.isEmpty) return null;

    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final atMs = decoded['fetchedAtMs'] as int? ?? 0;
      final rows = decoded['entries'] as List<dynamic>? ?? const [];
      final entries = [
        for (final row in rows)
          if (row is Map<String, dynamic>) _entryFromJson(row),
      ];
      final batch = CachedChasersBatch(
        fetchedAt: DateTime.fromMillisecondsSinceEpoch(atMs),
        entries: entries,
      );
      _memory = batch;
      return batch;
    } catch (_) {
      return null;
    }
  }

  void writeMemory(List<ChasersHeatEntry> entries) {
    _memory = CachedChasersBatch(
      fetchedAt: DateTime.now(),
      entries: List<ChasersHeatEntry>.unmodifiable(entries),
    );
  }

  Future<void> write(List<ChasersHeatEntry> entries) async {
    writeMemory(entries);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _prefsKey,
      jsonEncode({
        'fetchedAtMs': DateTime.now().millisecondsSinceEpoch,
        'entries': [for (final e in entries) _entryToJson(e)],
      }),
    );
  }

  static Map<String, dynamic> _entryToJson(ChasersHeatEntry entry) {
    final listing = entry.representativeListing;
    return {
      'identityLabel': entry.identityLabel,
      'clusterKey': entry.clusterKey,
      'heatScore': entry.heatScore,
      'listingCount': entry.listingCount,
      'uniqueSellerCount': entry.uniqueSellerCount,
      'brandId': entry.brandId,
      'ipId': entry.ipId,
      'ipLabel': entry.ipLabel,
      'listing': _listingToJson(listing),
    };
  }

  static ChasersHeatEntry _entryFromJson(Map<String, dynamic> json) {
    final listingJson = json['listing'] as Map<String, dynamic>? ?? const {};
    return ChasersHeatEntry(
      identityLabel: json['identityLabel'] as String? ?? '',
      clusterKey: json['clusterKey'] as String? ?? '',
      representativeListing: _listingFromJson(listingJson),
      heatScore: (json['heatScore'] as num?)?.toDouble() ?? 0,
      listingCount: json['listingCount'] as int? ?? 0,
      uniqueSellerCount: json['uniqueSellerCount'] as int? ?? 0,
      brandId: json['brandId'] as String? ?? '',
      ipId: json['ipId'] as String? ?? '',
      ipLabel: json['ipLabel'] as String? ?? '',
    );
  }

  static Map<String, dynamic> _listingToJson(MarketListing listing) {
    return {
      'id': listing.id,
      'providerId': listing.providerId,
      'providerListingId': listing.providerListingId,
      'externalListingUrl': listing.externalListingUrl,
      'name': listing.collectible.name,
      'imageUrl': listing.collectible.imageUrl,
      'currentPriceUsd': listing.currentPriceUsd,
      'priceChangePercent': listing.priceChangePercent,
      'listingCount': listing.listingCount,
      'sellerUsername': listing.sellerUsername,
    };
  }

  static MarketListing _listingFromJson(Map<String, dynamic> json) {
    final id = json['id'] as String? ?? '';
    return MarketListing(
      id: id,
      providerId: json['providerId'] as String? ?? 'ebay',
      providerListingId: json['providerListingId'] as String?,
      externalListingUrl: json['externalListingUrl'] as String?,
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
      sellerUsername: json['sellerUsername'] as String?,
    );
  }
}
