import 'package:blindbox_app/features/collection/insights/domain/collector_type_stats.dart';
import 'package:blindbox_app/features/collection/insights/widgets/collector_type_shelf_progress_card.dart';
import 'package:blindbox_app/features/collection/presentation/collection_vocabulary.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shelf progress card shows percent and series count', (
    tester,
  ) async {
    const stats = CollectorTypeStats(
      totalOwned: 11,
      totalWishlist: 2,
      trackedSeries: 5,
      completionPercent: 23,
      secretOwned: 1,
      secretSlots: 2,
      brandBreakdown: {},
      topSeries: [],
      customSeriesRatio: 0,
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: CollectorTypeShelfProgressCard(stats: stats),
        ),
      ),
    );

    expect(find.text('Shelf Progress'), findsOneWidget);
    expect(find.text('23%'), findsOneWidget);
    expect(
      find.text('5 ${CollectionVocabulary.series}'),
      findsOneWidget,
    );
  });
}
