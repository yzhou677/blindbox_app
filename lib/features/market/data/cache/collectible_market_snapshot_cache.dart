import 'dart:convert';

import 'package:blindbox_app/features/market/data/sandbox/market_sandbox_config.dart';
import 'package:blindbox_app/features/market/domain/aggregation_confidence.dart';
import 'package:blindbox_app/features/market/domain/collectible_market_grouping_tier.dart';
import 'package:blindbox_app/features/market/domain/collectible_market_identity.dart';
import 'package:blindbox_app/features/market/domain/collectible_market_snapshot.dart';
import 'package:blindbox_app/features/market/domain/market_mood.dart';
import 'package:blindbox_app/features/market/domain/observed_price_range.dart';
import 'package:blindbox_app/features/market/domain/rarity_presence.dart';
import 'package:shared_preferences/shared_preferences.dart';

final class CachedCollectibleMarketBatch {
  const CachedCollectibleMarketBatch({
    required this.fetchedAt,
    required this.snapshots,
  });

  final DateTime fetchedAt;
  final List<CollectibleMarketSnapshot> snapshots;

  bool isFresh({Duration? ttl}) {
    final maxAge = ttl ?? MarketSandboxConfig.cacheTtl;
    return DateTime.now().difference(fetchedAt) <= maxAge;
  }
}

/// Lightweight snapshot cache for offline-first market intelligence.
final class CollectibleMarketSnapshotCache {
  CollectibleMarketSnapshotCache._();

  static final CollectibleMarketSnapshotCache instance =
      CollectibleMarketSnapshotCache._();

  static const _prefsKey = 'collectible_market_snapshots_v1';

  CachedCollectibleMarketBatch? _memory;

  List<CollectibleMarketSnapshot>? readStale({bool allowExpired = true}) {
    final batch = _memory;
    if (batch == null) return null;
    if (!allowExpired && !batch.isFresh()) return null;
    return batch.snapshots;
  }

  Future<List<CollectibleMarketSnapshot>?> readStaleFromDisk() async {
    final mem = readStale();
    if (mem != null) return mem;

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null || raw.isEmpty) return null;

    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final atMs = decoded['fetchedAtMs'] as int? ?? 0;
      final rows = decoded['snapshots'] as List<dynamic>? ?? const [];
      final snapshots = [
        for (final m in rows)
          if (m is Map<String, dynamic>) _snapshotFromJson(m),
      ];
      _memory = CachedCollectibleMarketBatch(
        fetchedAt: DateTime.fromMillisecondsSinceEpoch(atMs),
        snapshots: snapshots,
      );
      return snapshots;
    } catch (_) {
      return null;
    }
  }

  void writeMemory(List<CollectibleMarketSnapshot> snapshots) {
    _memory = CachedCollectibleMarketBatch(
      fetchedAt: DateTime.now(),
      snapshots: List<CollectibleMarketSnapshot>.unmodifiable(snapshots),
    );
  }

  Future<void> write(List<CollectibleMarketSnapshot> snapshots) async {
    writeMemory(snapshots);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _prefsKey,
      jsonEncode({
        'fetchedAtMs': DateTime.now().millisecondsSinceEpoch,
        'snapshots': [for (final s in snapshots) _snapshotToJson(s)],
      }),
    );
  }

  void clear() => _memory = null;

  static Map<String, dynamic> _snapshotToJson(CollectibleMarketSnapshot s) {
    return {
      'snapshotId': s.identity.snapshotId,
      'groupingTier': s.identity.groupingTier.name,
      'matchedFigureId': s.identity.matchedFigureId,
      'matchedSeriesId': s.identity.matchedSeriesId,
      'matchedBrandId': s.identity.matchedBrandId,
      'matchedIpId': s.identity.matchedIpId,
      'listingCount': s.listingCount,
      'listingIds': s.listingIds,
      'providerCoverage': s.providerCoverage,
      'minUsd': s.observedPriceRange.minUsd,
      'maxUsd': s.observedPriceRange.maxUsd,
      'representativeListingId': s.representativeListingId,
      'marketMood': s.marketMood.name,
      'rarityPresence': s.rarityPresence.name,
      'aggregationConfidence': s.aggregationConfidence.name,
      'lastObservedAtMs': s.lastObservedAt.millisecondsSinceEpoch,
    };
  }

  static CollectibleMarketSnapshot _snapshotFromJson(Map<String, dynamic> json) {
    return CollectibleMarketSnapshot(
      identity: CollectibleMarketIdentity(
        snapshotId: json['snapshotId'] as String? ?? '',
        groupingTier: CollectibleMarketGroupingTier.values.byName(
          json['groupingTier'] as String? ?? 'listingFallback',
        ),
        matchedFigureId: json['matchedFigureId'] as String?,
        matchedSeriesId: json['matchedSeriesId'] as String?,
        matchedBrandId: json['matchedBrandId'] as String?,
        matchedIpId: json['matchedIpId'] as String?,
      ),
      listingCount: json['listingCount'] as int? ?? 0,
      listingIds: [
        for (final id in json['listingIds'] as List<dynamic>? ?? const [])
          if (id is String) id,
      ],
      providerCoverage: {
        for (final e
            in (json['providerCoverage'] as Map<String, dynamic>? ?? const {})
                .entries)
          e.key: (e.value as num?)?.toInt() ?? 0,
      },
      observedPriceRange: ObservedPriceRange(
        minUsd: (json['minUsd'] as num?)?.toDouble() ?? 0,
        maxUsd: (json['maxUsd'] as num?)?.toDouble() ?? 0,
      ),
      representativeListingId:
          json['representativeListingId'] as String? ?? '',
      marketMood: MarketMood.values.byName(
        json['marketMood'] as String? ?? 'mixed',
      ),
      rarityPresence: RarityPresence.values.byName(
        json['rarityPresence'] as String? ?? 'none',
      ),
      aggregationConfidence: AggregationConfidence.values.byName(
        json['aggregationConfidence'] as String? ?? 'none',
      ),
      lastObservedAt: DateTime.fromMillisecondsSinceEpoch(
        json['lastObservedAtMs'] as int? ?? 0,
      ),
    );
  }
}
