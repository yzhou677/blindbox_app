import 'package:blindbox_app/features/market_intel/domain/market_snapshot.dart';

/// DEV ONLY — predefined fallback validation cases for [MarketSnapshotDevScreen].
class MarketSnapshotDevCase {
  const MarketSnapshotDevCase({
    required this.label,
    required this.figureId,
    required this.expectedSummary,
  });

  final String label;
  final String figureId;
  final String expectedSummary;
}

/// DEV ONLY
const marketSnapshotDevCases = <MarketSnapshotDevCase>[
  MarketSnapshotDevCase(
    label: 'Case A — figure snapshot',
    figureId: 'the_monsters_big_into_energy_vinyl_plush_pendant_luck',
    expectedSummary:
        'Figure snapshot returned (~\$42 · Rising · 18 sales · high confidence)',
  ),
  MarketSnapshotDevCase(
    label: 'Case B — series fallback',
    figureId: 'the_monsters_big_into_energy_vinyl_plush_pendant_hope',
    expectedSummary:
        'Series snapshot returned (~\$37 · Stable · 4 sales* · low confidence)',
  ),
  MarketSnapshotDevCase(
    label: 'Case C — missing snapshot',
    figureId: 'the_monsters_big_into_energy_vinyl_plush_pendant_serenity',
    expectedSummary: 'Null — no badge',
  ),
];

/// DEV ONLY
String describeMarketSnapshot(MarketSnapshot? snapshot) {
  if (snapshot == null) return 'Not found';

  final trend = switch (snapshot.trend) {
    MarketTrend.rising => 'rising',
    MarketTrend.falling => 'falling',
    MarketTrend.stable => 'stable',
    MarketTrend.unknown => 'unknown',
  };

  return [
    'Found (${snapshot.level.name})',
    'value=\$${snapshot.estimatedValueUsd.round()}',
    'trend=$trend',
    'sales=${snapshot.recentSalesCount}',
    'confidence=${snapshot.confidence.name}',
    if (snapshot.isSeriesEstimate) 'seriesEstimate=true',
  ].join(' · ');
}
