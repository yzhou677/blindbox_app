import 'package:flutter/foundation.dart';

import 'package:blindbox_app/features/market/domain/market_listing_title_signals.dart';

/// Lightweight title cluster for market-heat spike — identity-level grouping from seller titles.
@immutable
class MarketTitleCluster {
  const MarketTitleCluster({
    required this.clusterKey,
    required this.label,
    required this.listingCount,
    required this.uniqueSellerCount,
    required this.noiseListingCount,
    required this.accessoryListingCount,
    required this.sampleTitles,
    required this.medianPriceUsd,
  });

  final String clusterKey;
  final String label;
  final int listingCount;
  final int uniqueSellerCount;
  final int noiseListingCount;
  final int accessoryListingCount;
  final List<String> sampleTitles;
  final double? medianPriceUsd;

  double get sellerDiversity =>
      listingCount == 0 ? 0 : uniqueSellerCount / listingCount;

  bool get likelyAccessoryHeavy =>
      listingCount > 0 && accessoryListingCount / listingCount >= 0.5;

  bool get likelyNoisy =>
      listingCount > 0 && noiseListingCount / listingCount >= 0.34;
}

@immutable
class MarketTitleClusterInput {
  const MarketTitleClusterInput({
    required this.title,
    this.sellerUsername,
    this.priceUsd,
  });

  final String title;
  final String? sellerUsername;
  final double? priceUsd;
}

/// Prototype clusterer — shared algorithm with `functions/tools/lib/market-title-cluster.mjs`.
class MarketTitleClusterer {
  const MarketTitleClusterer({
    this.hintTokens = const [],
    this.minClusterSize = 2,
  });

  final List<String> hintTokens;
  final int minClusterSize;

  static const _stopwords = {
    'pop', 'mart', 'popmart', 'the', 'and', 'for', 'with', 'from', 'new',
    'box', 'blind', 'figure', 'figurine', 'vinyl', 'plush', 'toy', 'toys',
    'series', 'set', 'lot', 'authentic', 'official', 'sealed', 'confirmed',
    'open', 'brand', 'rare', 'cute', 'gift', 'us', 'seller', 'free', 'ship',
    'shipping', 'pre', 'order', 'preorder', 'sale', 'hot', '2024', '2025',
    '2026', 'pcs', 'pc', 'pack', 'case', 'only', 'one', 'single', 'pick',
    'choose', 'your', 'you', 'like', 'style', 'design', 'edition', 'global',
  };

  List<MarketTitleCluster> cluster(List<MarketTitleClusterInput> rows) {
    if (rows.isEmpty) return const [];

    final buckets = <String, List<MarketTitleClusterInput>>{};
    for (final row in rows) {
      final key = clusterKeyForTitle(row.title);
      buckets.putIfAbsent(key, () => []).add(row);
    }

    final out = <MarketTitleCluster>[];
    for (final entry in buckets.entries) {
      if (entry.value.length < minClusterSize) continue;
      final titles = entry.value.map((e) => e.title).toList(growable: false);
      final sellers = entry.value
          .map((e) => e.sellerUsername?.trim().toLowerCase())
          .whereType<String>()
          .where((s) => s.isNotEmpty)
          .toSet();
      var noise = 0;
      var accessory = 0;
      for (final row in entry.value) {
        if (_hasNoise(row.title)) noise++;
        if (_hasAccessory(row.title)) accessory++;
      }
      final prices = entry.value
          .map((e) => e.priceUsd)
          .whereType<double>()
          .where((p) => p > 0)
          .toList()
        ..sort();
      out.add(
        MarketTitleCluster(
          clusterKey: entry.key,
          label: clusterLabelForKey(entry.key),
          listingCount: entry.value.length,
          uniqueSellerCount: sellers.length,
          noiseListingCount: noise,
          accessoryListingCount: accessory,
          sampleTitles: titles.take(3).toList(growable: false),
          medianPriceUsd: prices.isEmpty ? null : _median(prices),
        ),
      );
    }

    out.sort((a, b) {
      final byCount = b.listingCount.compareTo(a.listingCount);
      if (byCount != 0) return byCount;
      return b.uniqueSellerCount.compareTo(a.uniqueSellerCount);
    });
    return out;
  }

  String clusterKeyForTitle(String title) {
    final tokens = _significantTokens(title);
    if (tokens.isEmpty) return 'cluster:unknown';
    final hint = hintTokens
        .map((t) => t.trim().toLowerCase())
        .where((t) => t.isNotEmpty)
        .toList();
    final matched = tokens.where((t) => hint.contains(t)).toList();
    final core = matched.isNotEmpty
        ? matched
        : tokens.take(3).toList();
    if (core.isEmpty) return 'cluster:unknown';
    final sorted = [...core]..sort();
    return 'cluster:${sorted.join('|')}';
  }

  String clusterLabelForKey(String clusterKey) {
    final raw = clusterKey.startsWith('cluster:')
        ? clusterKey.substring('cluster:'.length)
        : clusterKey;
    if (raw.isEmpty || raw == 'unknown') return 'Unknown';
    return raw.split('|').map(_titleCaseToken).join(' ');
  }

  List<String> _significantTokens(String title) {
    final normalized = title
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), ' ')
        .split(RegExp(r'\s+'))
        .map((w) => w.trim())
        .where((w) => w.length > 2)
        .where((w) => !_stopwords.contains(w))
        .where((w) => !RegExp(r'^\d+$').hasMatch(w))
        .toList();
    return normalized;
  }

  bool _hasNoise(String title) => MarketListingTitleSignals.isNoisy(title);

  bool _hasAccessory(String title) =>
      MarketListingTitleSignals.isAccessory(title);

  static double _median(List<double> sorted) {
    final mid = sorted.length ~/ 2;
    if (sorted.length.isOdd) return sorted[mid];
    return (sorted[mid - 1] + sorted[mid]) / 2;
  }

  static String _titleCaseToken(String raw) {
    if (raw.isEmpty) return raw;
    if (raw.length <= 3) return raw.toUpperCase();
    return raw[0].toUpperCase() + raw.substring(1);
  }
}
