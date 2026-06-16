import 'package:blindbox_app/features/catalog/application/catalog_bundle_cache.dart';
import 'package:blindbox_app/features/market_intel/domain/market_snapshot.dart';
import 'package:blindbox_app/features/market/utils/market_format.dart';
import 'package:blindbox_app/features/official_feed/presentation/official_feed_relative_time.dart';

/// User-facing label for blind-box series-level fallback estimates (badge chip).
const String kMarketSnapshotSeriesEstimateLabel = 'Series Estimate';

/// Compact series-average label (Discover summary, Insights card column).
const String kMarketSnapshotSeriesAvgLabel = 'Series Avg.';

/// Badge heading when snapshot is a blind-box series-level fallback.
const String kMarketSnapshotSeriesAvgValueBadgeHeading = 'Series Avg. Value';

/// Product-level market estimate for non-blind-box series fallbacks.
const String kMarketSnapshotMarketEstimateLabel = 'Market Estimate';

/// Insights screen banner for blind-box series fallback.
const String kMarketSnapshotInsightsSeriesLevelEstimateLabel =
    'Series-Level Estimate';

/// Discover gallery accordion heading.
const String kMarketSnapshotDiscoverDisclosureHeading = 'Market Information';

/// Semantics label for blind-box Tier B delta info affordance.
const String kMarketSeriesAverageInfoSemanticsLabel =
    'About series average pricing';

/// Semantics label for non-blind-box Tier B delta info affordance.
const String kMarketMarketEstimateInfoSemanticsLabel =
    'About this market estimate';

/// Bottom sheet title for blind-box Tier B listing price comparison.
const String kMarketSeriesAverageInfoSheetTitle = 'About series average pricing';

/// Bottom sheet title for non-blind-box Tier B listing price comparison.
const String kMarketMarketEstimateInfoSheetTitle =
    'About this market estimate';

/// Returns [true] when [seriesId] maps to a blind-box catalog series.
///
/// Defaults to blind-box wording when the catalog bundle is unavailable or the
/// series is missing — preserves existing Hope / Big Into Energy copy.
bool resolveIsBlindBoxSeries(String seriesId) {
  final trimmed = seriesId.trim();
  if (trimmed.isEmpty) return true;

  final bundle = CatalogBundleCache.current;
  if (bundle == null) return true;

  for (final series in bundle.series) {
    if (series.id == trimmed) {
      return series.isBlindBox;
    }
  }
  return true;
}

/// Value column label for market snapshot surfaces.
String snapshotTierValueLabel(MarketSnapshot snapshot) {
  if (!snapshot.isSeriesEstimate) return 'Market Value';
  if (!resolveIsBlindBoxSeries(snapshot.seriesId)) {
    return kMarketSnapshotMarketEstimateLabel;
  }
  return kMarketSnapshotSeriesAvgLabel;
}

/// Banner above purchase context on [MarketInsightsScreen] for Tier B.
String snapshotTierBBannerLabel(MarketSnapshot snapshot) {
  if (!resolveIsBlindBoxSeries(snapshot.seriesId)) {
    return kMarketSnapshotMarketEstimateLabel;
  }
  return kMarketSnapshotInsightsSeriesLevelEstimateLabel;
}

/// Badge heading for Tier B snapshots.
String snapshotTierBBadgeHeadingLabel(MarketSnapshot snapshot) {
  if (!resolveIsBlindBoxSeries(snapshot.seriesId)) {
    return kMarketSnapshotMarketEstimateLabel;
  }
  return kMarketSnapshotSeriesAvgValueBadgeHeading;
}

/// Chip label for Tier B snapshots (without leading ≈).
String snapshotTierBEstimateChipLabel(MarketSnapshot snapshot) {
  if (!resolveIsBlindBoxSeries(snapshot.seriesId)) {
    return kMarketSnapshotMarketEstimateLabel;
  }
  return kMarketSnapshotSeriesEstimateLabel;
}

/// Info sheet title for Tier B delta disclosure.
String snapshotTierBInfoSheetTitle(MarketSnapshot snapshot) {
  if (!resolveIsBlindBoxSeries(snapshot.seriesId)) {
    return kMarketMarketEstimateInfoSheetTitle;
  }
  return kMarketSeriesAverageInfoSheetTitle;
}

/// Semantics label for Tier B delta info affordance.
String snapshotTierBInfoSemanticsLabel(MarketSnapshot snapshot) {
  if (!resolveIsBlindBoxSeries(snapshot.seriesId)) {
    return kMarketMarketEstimateInfoSemanticsLabel;
  }
  return kMarketSeriesAverageInfoSemanticsLabel;
}

/// Collapsed / expanded disclosure row — e.g. `▶ Market Information`.
String formatMarketSnapshotDiscoverDisclosureLabel({required bool expanded}) {
  final chevron = expanded ? '▼' : '▶';
  return '$chevron $kMarketSnapshotDiscoverDisclosureHeading';
}

/// Formats [estimatedValueUsd] for dominant display (no tilde prefix).
String formatMarketSnapshotValue(double estimatedValueUsd) {
  return formatMarketUsd(estimatedValueUsd);
}

/// Plain sales segment for Discover summary (no confidence asterisk).
String? formatMarketSnapshotDiscoverSalesSegment(MarketSnapshot snapshot) {
  if (snapshot.recentSalesCount <= 0) return null;
  return '${snapshot.recentSalesCount} sales';
}

/// Expanded Discover panel — e.g. `18 recent sales`.
String? formatMarketSnapshotDiscoverRecentSalesLine(MarketSnapshot snapshot) {
  if (snapshot.recentSalesCount <= 0) return null;
  return '${snapshot.recentSalesCount} recent sales';
}

/// Expanded Discover panel — e.g. `$38–$48` (no “range” suffix).
String? formatMarketSnapshotDiscoverPriceRangeValue(MarketSnapshot snapshot) {
  final min = snapshot.priceRangeMinUsd;
  final max = snapshot.priceRangeMaxUsd;
  if (min == null || max == null) return null;
  return '${formatMarketUsd(min)}–${formatMarketUsd(max)}';
}

/// Discover gallery expanded body — value and sales (not shown when collapsed).
///
/// Figure snapshot: `Market Value · $42 · 18 sales`
/// Blind-box series fallback: `Series Avg. · $37 · 4 sales`
/// Non-blind-box series fallback: `Market Estimate · $1,240 · 6 sales`
String formatMarketSnapshotDiscoverSummaryLine(MarketSnapshot snapshot) {
  final value = formatMarketSnapshotValue(snapshot.estimatedValueUsd);
  final head = '${snapshotTierValueLabel(snapshot)} · $value';
  final sales = formatMarketSnapshotDiscoverSalesSegment(snapshot);
  if (sales == null) return head;
  return '$head · $sales';
}

/// Returns e.g. `18 sales`. Null when [recentSalesCount] <= 0.
String? formatMarketSnapshotSalesLine(MarketSnapshot snapshot) {
  if (snapshot.recentSalesCount <= 0) return null;
  return '${snapshot.recentSalesCount} sales';
}

/// Returns e.g. `$38–$48 range`. Null when min or max is missing.
String? formatMarketSnapshotPriceRangeLine(MarketSnapshot snapshot) {
  final min = snapshot.priceRangeMinUsd;
  final max = snapshot.priceRangeMaxUsd;
  if (min == null || max == null) return null;

  return '${formatMarketUsd(min)}–${formatMarketUsd(max)} range';
}

/// Returns e.g. `Updated 3d ago` or `Updated Jun 15`.
String formatMarketSnapshotUpdatedLine(
  DateTime computedAt, {
  DateTime? clock,
}) {
  final relative = formatOfficialFeedRelativeTime(computedAt, clock: clock);
  return 'Updated $relative';
}

/// Market listing detail navigation row label.
const String kMarketDetailInsightsHeading = 'Market Insights';

/// Shown when snapshot load fails or no sold-data exists for the matched figure.
const String kMarketDetailInsightsUnavailable = 'Market insights unavailable';

/// Dedicated Market Insights screen title.
const String kMarketInsightsScreenTitle = 'Market Insights';

/// Footer on [MarketInsightsScreen].
const String kMarketInsightsScreenFooter =
    'Data is currently estimated from eBay listings and sales activity.\n'
    'Other marketplaces are not included.';

/// Data source section value on [MarketInsightsScreen].
const String kMarketInsightsDataSourceValue = 'eBay marketplace activity';

/// Trend label for listing detail. Null when [MarketTrend.unknown].
String? formatMarketSnapshotTrendLabel(MarketTrend trend) {
  return switch (trend) {
    MarketTrend.rising => 'Trending',
    MarketTrend.falling => 'Cooling',
    MarketTrend.stable => 'Stable',
    MarketTrend.unknown => null,
  };
}

/// Recent sales count for [MarketInsightsScreen] — e.g. `18`.
String formatMarketSnapshotInsightsRecentSalesCount(MarketSnapshot snapshot) {
  return '${snapshot.recentSalesCount}';
}

/// Activity line — e.g. `18 recent sales`.
String? formatMarketSnapshotInsightsActivitySalesLine(MarketSnapshot snapshot) {
  if (snapshot.recentSalesCount <= 0) return null;
  return '${snapshot.recentSalesCount} recent sales';
}

/// Secondary range line — e.g. `Range $38–$48`.
String? formatMarketSnapshotInsightsRangeLine(MarketSnapshot snapshot) {
  final range = formatMarketSnapshotDiscoverPriceRangeValue(snapshot);
  if (range == null) return null;
  return 'Range $range';
}

/// Secondary freshness line — e.g. `Updated 35h ago`.
String formatMarketSnapshotInsightsUpdatedMetadataLine(
  DateTime computedAt, {
  DateTime? clock,
}) {
  return 'Updated ${formatOfficialFeedRelativeTime(computedAt, clock: clock)}';
}

/// Relative freshness for [MarketInsightsScreen] — e.g. `35h ago`.
String formatMarketSnapshotInsightsUpdatedValue(
  DateTime computedAt, {
  DateTime? clock,
}) {
  return formatOfficialFeedRelativeTime(computedAt, clock: clock);
}

/// Compares listing ask price to sold-data estimate.
///
/// Tier A (figure snapshot): `▲ N% above market`, `✓ Below market`, `≈ At market`.
/// Tier B blind-box: `▲ N% above series avg.`, `Below series avg.`, `≈ Near series avg.`
/// Tier B non-blind-box: `▲ N% above market estimate`, etc.
String? formatMarketListingPriceDeltaLine(
  double listingPriceUsd,
  double estimatedValueUsd, {
  required bool isSeriesEstimate,
  String? seriesId,
}) {
  if (estimatedValueUsd <= 0) return null;

  final ratio = (listingPriceUsd - estimatedValueUsd) / estimatedValueUsd;
  if (!isSeriesEstimate) {
    if (ratio > 0.05) {
      final pct = (ratio * 100).round();
      return '▲ $pct% above market';
    }
    if (ratio < -0.05) {
      return '✓ Below market';
    }
    return '≈ At market';
  }

  final blindBox = resolveIsBlindBoxSeries(seriesId ?? '');
  if (!blindBox) {
    if (ratio > 0.05) {
      final pct = (ratio * 100).round();
      return '▲ $pct% above market estimate';
    }
    if (ratio < -0.05) {
      return 'Below market estimate';
    }
    return '≈ Near market estimate';
  }

  if (ratio > 0.05) {
    final pct = (ratio * 100).round();
    return '▲ $pct% above series avg.';
  }
  if (ratio < -0.05) {
    return 'Below series avg.';
  }
  return '≈ Near series avg.';
}
