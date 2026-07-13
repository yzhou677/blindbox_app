import 'package:blindbox_app/features/collection/insights/domain/collector_type_stats.dart';
import 'package:blindbox_app/features/collection/insights/widgets/collector_type_shelf_progress_card.dart';
import 'package:blindbox_app/features/collection/presentation/collection_vocabulary.dart';
import 'package:blindbox_app/features/collection/widgets/collection_insights_compact_summary.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

CollectorTypeStats _stats({
  int completionPercent = 23,
  int trackedSeries = 5,
  int masterCompleteSeriesCount = 0,
  int completedSeriesCount = 0,
}) {
  return CollectorTypeStats(
    totalOwned: 11,
    totalWishlist: 2,
    trackedSeries: trackedSeries,
    completedSeriesCount: completedSeriesCount,
    masterCompleteSeriesCount: masterCompleteSeriesCount,
    completionPercent: completionPercent,
    secretOwned: 1,
    secretSlots: 2,
    brandBreakdown: {},
    topSeries: [],
    customSeriesRatio: 0,
  );
}

void main() {
  group('ShelfProgressPresentation', () {
    test('hides Master Completion until first master series', () {
      expect(
        ShelfProgressPresentation.showMasterCompletion(
          _stats(masterCompleteSeriesCount: 0),
        ),
        isFalse,
      );
      expect(
        ShelfProgressPresentation.showMasterCompletion(
          _stats(masterCompleteSeriesCount: 1),
        ),
        isTrue,
      );
    });

    test('master ratio uses existing series counts only', () {
      expect(
        ShelfProgressPresentation.masterCompletionRatio(
          _stats(trackedSeries: 5, masterCompleteSeriesCount: 2),
        ),
        0.4,
      );
      expect(
        ShelfProgressPresentation.masterCompletionPercent(
          _stats(trackedSeries: 5, masterCompleteSeriesCount: 2),
        ),
        40,
      );
      expect(
        ShelfProgressPresentation.masterCompletionRatio(
          _stats(trackedSeries: 0, masterCompleteSeriesCount: 0),
        ),
        0,
      );
    });
  });

  testWidgets('stage 1 shows Regular Completion only', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CollectorTypeShelfProgressCard(
            stats: _stats(masterCompleteSeriesCount: 0),
          ),
        ),
      ),
    );

    expect(find.text('Shelf Progress'), findsOneWidget);
    expect(find.text(CollectionVocabulary.regularCompletion), findsOneWidget);
    expect(find.text('23%'), findsOneWidget);
    expect(find.text(CollectionVocabulary.masterCompletion), findsNothing);
    expect(
      find.text(CollectionInsightsCompactSummaryFormat.masterCompleteGlyph),
      findsNothing,
    );
    expect(
      find.text('5 ${CollectionVocabulary.series}'),
      findsNothing,
    );
  });

  testWidgets('stage 2 reveals subordinate Master Completion', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CollectorTypeShelfProgressCard(
            stats: _stats(
              completionPercent: 80,
              trackedSeries: 5,
              completedSeriesCount: 4,
              masterCompleteSeriesCount: 2,
            ),
          ),
        ),
      ),
    );

    expect(find.text(CollectionVocabulary.regularCompletion), findsOneWidget);
    expect(find.text('80%'), findsOneWidget);
    expect(find.text(CollectionVocabulary.masterCompletion), findsOneWidget);
    expect(find.text('40%'), findsOneWidget);
    expect(
      find.text(CollectionInsightsCompactSummaryFormat.masterCompleteGlyph),
      findsOneWidget,
    );
  });
}
