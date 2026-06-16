import 'package:blindbox_app/features/market_intel/domain/market_snapshot.dart';
import 'package:blindbox_app/features/market/utils/market_format.dart';
import 'package:blindbox_app/features/official_feed/presentation/official_feed_relative_time.dart';

/// User-facing label for series-level fallback estimates (badge chip).
const String kMarketSnapshotSeriesEstimateLabel = 'Series Estimate';

/// Compact series-average label (Discover summary, Insights card column).
const String kMarketSnapshotSeriesAvgLabel = 'Series Avg.';

/// Badge heading when snapshot is a series-level fallback.
const String kMarketSnapshotSeriesAvgValueBadgeHeading = 'Series Avg. Value';

/// Insights screen label above purchase context for series fallback.
const String kMarketSnapshotInsightsSeriesLevelEstimateLabel =
    'Series-Level Estimate';

/// Discover gallery accordion heading.
const String kMarketSnapshotDiscoverDisclosureHeading = 'Market Information';

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
/// Series fallback: `Series Avg. · $37 · 4 sales`
String formatMarketSnapshotDiscoverSummaryLine(MarketSnapshot snapshot) {
  final value = formatMarketSnapshotValue(snapshot.estimatedValueUsd);
  final head = snapshot.isSeriesEstimate
      ? '$kMarketSnapshotSeriesAvgLabel · $value'
      : 'Market Value · $value';
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
/// Tier B (series estimate): `▲ N% above series avg.`, `Below series avg.`,
/// `≈ Near series avg.`
String? formatMarketListingPriceDeltaLine(
  double listingPriceUsd,
  double estimatedValueUsd, {
  required bool isSeriesEstimate,
}) {
  if (estimatedValueUsd <= 0) return null;

  final ratio = (listingPriceUsd - estimatedValueUsd) / estimatedValueUsd;
  if (ratio > 0.05) {
    final pct = (ratio * 100).round();
    return isSeriesEstimate
        ? '▲ $pct% above series avg.'
        : '▲ $pct% above market';
  }
  if (ratio < -0.05) {
    return isSeriesEstimate ? 'Below series avg.' : '✓ Below market';
  }
  return isSeriesEstimate ? '≈ Near series avg.' : '≈ At market';
}
