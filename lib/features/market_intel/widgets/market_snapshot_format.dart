import 'package:blindbox_app/features/market_intel/domain/market_snapshot.dart';
import 'package:blindbox_app/features/market/utils/market_format.dart';
import 'package:blindbox_app/features/official_feed/presentation/official_feed_relative_time.dart';

/// User-facing label for series-level fallback estimates (badge chip).
const String kMarketSnapshotSeriesEstimateLabel = 'Series Estimate';

/// Discover gallery series-fallback prefix.
const String kMarketSnapshotDiscoverSeriesFallbackLabel =
    'Using Series Estimate';

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
/// Series fallback: `Using Series Estimate · $37 · 4 sales`
String formatMarketSnapshotDiscoverSummaryLine(MarketSnapshot snapshot) {
  final value = formatMarketSnapshotValue(snapshot.estimatedValueUsd);
  final head = snapshot.isSeriesEstimate
      ? '$kMarketSnapshotDiscoverSeriesFallbackLabel · $value'
      : 'Market Value · $value';
  final sales = formatMarketSnapshotDiscoverSalesSegment(snapshot);
  if (sales == null) return head;
  return '$head · $sales';
}

/// Returns e.g. `18 sales` or `4 sales*` when confidence is low.
/// Null when [recentSalesCount] <= 0.
String? formatMarketSnapshotSalesLine(MarketSnapshot snapshot) {
  if (snapshot.recentSalesCount <= 0) return null;

  final suffix =
      snapshot.confidence == SnapshotConfidence.low ? '*' : '';
  return '${snapshot.recentSalesCount} sales$suffix';
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
