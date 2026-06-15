import 'package:blindbox_app/core/theme/app_theme.dart';
import 'package:blindbox_app/features/market_intel/domain/market_snapshot.dart';
import 'package:blindbox_app/features/market_intel/widgets/market_snapshot_badge.dart';
import 'package:blindbox_app/features/market_intel/widgets/market_snapshot_format.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

MarketSnapshot _figureSnapshot() {
  return MarketSnapshot(
    id: 'the_monsters_big_into_energy_vinyl_plush_pendant_luck',
    level: SnapshotLevel.figure,
    figureId: 'the_monsters_big_into_energy_vinyl_plush_pendant_luck',
    seriesId: 'the_monsters_big_into_energy_vinyl_plush_pendant',
    estimatedValueUsd: 42,
    trend: MarketTrend.rising,
    confidence: SnapshotConfidence.high,
    recentSalesCount: 18,
    priceRangeMinUsd: 38,
    priceRangeMaxUsd: 48,
    computedAt: DateTime.utc(2026, 6, 15),
  );
}

MarketSnapshot _seriesSnapshot() {
  return MarketSnapshot(
    id: 'the_monsters_big_into_energy_vinyl_plush_pendant',
    level: SnapshotLevel.series,
    seriesId: 'the_monsters_big_into_energy_vinyl_plush_pendant',
    estimatedValueUsd: 37,
    trend: MarketTrend.stable,
    confidence: SnapshotConfidence.low,
    recentSalesCount: 4,
    priceRangeMinUsd: 30,
    priceRangeMaxUsd: 45,
    computedAt: DateTime.utc(2026, 6, 15),
  );
}

Future<void> _pumpBadge(WidgetTester tester, MarketSnapshot snapshot) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: Center(child: MarketSnapshotBadge(snapshot: snapshot)),
      ),
    ),
  );
}

void main() {
  testWidgets('figure snapshot shows value, sales, range, and freshness', (
    tester,
  ) async {
    await _pumpBadge(tester, _figureSnapshot());

    expect(find.text('Market Value'), findsOneWidget);
    expect(find.text('\$42'), findsOneWidget);
    expect(find.text('18 sales'), findsOneWidget);
    expect(find.text('\$38–\$48 range'), findsOneWidget);
    expect(find.textContaining('Updated'), findsOneWidget);
    expect(find.textContaining(kMarketSnapshotSeriesEstimateLabel), findsNothing);
  });

  testWidgets('series fallback shows series estimate indicator', (
    tester,
  ) async {
    await _pumpBadge(tester, _seriesSnapshot());

    expect(find.text('\$37'), findsOneWidget);
    expect(
      find.text('≈ $kMarketSnapshotSeriesEstimateLabel'),
      findsOneWidget,
    );
    expect(find.text('4 sales*'), findsOneWidget);
    expect(find.text('\$30–\$45 range'), findsOneWidget);
  });

  testWidgets('hides sales line when count is zero', (tester) async {
    final snapshot = MarketSnapshot(
      id: 'fig',
      level: SnapshotLevel.figure,
      figureId: 'fig',
      seriesId: 'series',
      estimatedValueUsd: 10,
      trend: MarketTrend.unknown,
      confidence: SnapshotConfidence.low,
      recentSalesCount: 0,
      priceRangeMinUsd: 8,
      priceRangeMaxUsd: 12,
      computedAt: DateTime.utc(2026, 6, 15),
    );

    await _pumpBadge(tester, snapshot);

    expect(find.textContaining('sales'), findsNothing);
    expect(find.text('\$10'), findsOneWidget);
  });
}
