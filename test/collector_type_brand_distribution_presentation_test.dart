import 'package:blindbox_app/features/collection/insights/domain/collector_type_stats.dart';
import 'package:blindbox_app/features/collection/insights/widgets/collector_type_brand_donut.dart';
import 'package:blindbox_app/features/collection/insights/widgets/collector_type_stats_strip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('single brand uses emphasis row instead of donut', (tester) async {
    const stats = CollectorTypeStats(
      totalOwned: 4,
      totalWishlist: 0,
      trackedSeries: 2,
      completionPercent: 40,
      secretOwned: 0,
      secretSlots: 0,
      brandBreakdown: {'pop_mart': 4},
      topSeries: [],
      customSeriesRatio: 0,
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: CollectorTypeStatsStrip(stats: stats),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Brand distribution'), findsOneWidget);
    expect(find.text('100%'), findsOneWidget);
    expect(find.byType(CollectorTypeBrandDonut), findsNothing);
  });

  testWidgets('multi brand keeps donut visualization', (tester) async {
    const stats = CollectorTypeStats(
      totalOwned: 5,
      totalWishlist: 0,
      trackedSeries: 3,
      completionPercent: 50,
      secretOwned: 0,
      secretSlots: 0,
      brandBreakdown: {
        'pop_mart': 3,
        'finding_unicorn': 2,
      },
      topSeries: [],
      customSeriesRatio: 0,
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: CollectorTypeStatsStrip(stats: stats),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(CollectorTypeBrandDonut), findsOneWidget);
  });
}
