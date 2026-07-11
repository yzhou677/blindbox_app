import 'package:blindbox_app/features/collection/insights/domain/collector_type_stats.dart';
import 'package:blindbox_app/features/collection/insights/widgets/collector_type_totals_row.dart';
import 'package:blindbox_app/features/collection/presentation/collection_vocabulary.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('at-a-glance tiles use collection vocabulary', (tester) async {
    const stats = CollectorTypeStats(
      totalOwned: 11,
      totalWishlist: 2,
      trackedSeries: 3,
      completionPercent: 72,
      secretOwned: 1,
      secretSlots: 2,
      brandBreakdown: {},
      topSeries: [],
      customSeriesRatio: 0,
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: CollectorTypeTotalsRow(stats: stats),
        ),
      ),
    );

    expect(find.text('11'), findsOneWidget);
    expect(find.text(CollectionVocabulary.figures), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text(CollectionVocabulary.wishlist), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text(CollectionVocabulary.series), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(find.text(CollectionVocabulary.secretFigure), findsOneWidget);
    expect(find.textContaining(CollectionVocabulary.shelfProgress), findsNothing);
  });
}
