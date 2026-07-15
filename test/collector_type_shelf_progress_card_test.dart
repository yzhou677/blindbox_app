import 'package:blindbox_app/features/collection/insights/domain/collector_type_stats.dart';
import 'package:blindbox_app/features/collection/insights/widgets/collector_type_shelf_progress_card.dart';
import 'package:blindbox_app/features/collection/presentation/completion_metric_tooltips.dart';
import 'package:blindbox_app/features/collection/presentation/collection_vocabulary.dart';
import 'package:blindbox_app/features/collection/widgets/collection_insights_compact_summary.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

CollectorTypeStats _stats({
  int completionPercent = 23,
  int trackedSeries = 5,
  int masterCompleteSeriesCount = 0,
  int masterEligibleSeriesCount = 0,
  int completedSeriesCount = 0,
}) {
  return CollectorTypeStats(
    totalOwned: 11,
    totalWishlist: 2,
    trackedSeries: trackedSeries,
    completedSeriesCount: completedSeriesCount,
    masterCompleteSeriesCount: masterCompleteSeriesCount,
    masterEligibleSeriesCount: masterEligibleSeriesCount,
    completionPercent: completionPercent,
    secretOwned: 1,
    secretSlots: 2,
    brandBreakdown: {},
    topSeries: [],
    customSeriesRatio: 0,
  );
}

Finder _tooltipIcon(String message) =>
    find.byKey(ValueKey<String>('info-tooltip-$message'));

void main() {
  group('ShelfProgressPresentation', () {
    test('hides Master Completion until first master series', () {
      expect(
        ShelfProgressPresentation.showMasterCompletion(
          _stats(masterCompleteSeriesCount: 0, masterEligibleSeriesCount: 2),
        ),
        isFalse,
      );
      expect(
        ShelfProgressPresentation.showMasterCompletion(
          _stats(masterCompleteSeriesCount: 1, masterEligibleSeriesCount: 2),
        ),
        isTrue,
      );
    });

    test('master ratio uses Secret-bearing eligible denom only', () {
      expect(
        ShelfProgressPresentation.masterCompletionRatio(
          _stats(
            trackedSeries: 5,
            masterCompleteSeriesCount: 2,
            masterEligibleSeriesCount: 2,
          ),
        ),
        1.0,
      );
      expect(
        ShelfProgressPresentation.masterCompletionPercent(
          _stats(
            trackedSeries: 5,
            masterCompleteSeriesCount: 2,
            masterEligibleSeriesCount: 2,
          ),
        ),
        100,
      );
      expect(
        ShelfProgressPresentation.masterCompletionPercent(
          _stats(
            trackedSeries: 5,
            masterCompleteSeriesCount: 1,
            masterEligibleSeriesCount: 2,
          ),
        ),
        50,
      );
      expect(
        ShelfProgressPresentation.masterCompletionRatio(
          _stats(trackedSeries: 5, masterEligibleSeriesCount: 0),
        ),
        0,
      );
    });
  });

  testWidgets('stage 1 shows Regular Progress only', (tester) async {
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
    expect(find.text(CollectionVocabulary.regularProgress), findsOneWidget);
    expect(
      _tooltipIcon(CompletionMetricTooltips.regularProgress),
      findsOneWidget,
    );
    expect(find.text('23%'), findsOneWidget);
    expect(find.text(CollectionVocabulary.masterCompletion), findsNothing);
    expect(
      find.text(CollectionInsightsCompactSummaryFormat.masterCompleteGlyph),
      findsNothing,
    );
    expect(find.text('5 ${CollectionVocabulary.series}'), findsNothing);
  });

  testWidgets('stage 2 reveals Master Completion over eligible denom', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CollectorTypeShelfProgressCard(
            stats: _stats(
              completionPercent: 80,
              trackedSeries: 5,
              completedSeriesCount: 4,
              masterCompleteSeriesCount: 2,
              masterEligibleSeriesCount: 2,
            ),
          ),
        ),
      ),
    );

    expect(find.text(CollectionVocabulary.regularProgress), findsOneWidget);
    expect(find.text('80%'), findsOneWidget);
    expect(find.text(CollectionVocabulary.masterCompletion), findsOneWidget);
    expect(
      _tooltipIcon(CompletionMetricTooltips.masterCompletion),
      findsOneWidget,
    );
    expect(find.text('100%'), findsOneWidget);
    expect(
      find.text(CollectionInsightsCompactSummaryFormat.masterCompleteGlyph),
      findsOneWidget,
    );
  });

  testWidgets('metric tooltips open and dismiss', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CollectorTypeShelfProgressCard(
            stats: _stats(
              completionPercent: 80,
              trackedSeries: 5,
              completedSeriesCount: 4,
              masterCompleteSeriesCount: 2,
              masterEligibleSeriesCount: 2,
            ),
          ),
        ),
      ),
    );

    await tester.tap(_tooltipIcon(CompletionMetricTooltips.regularProgress));
    await tester.pump();
    expect(find.text(CompletionMetricTooltips.regularProgress), findsOneWidget);

    await tester.tapAt(const Offset(1, 1));
    await tester.pumpAndSettle();
    expect(find.text(CompletionMetricTooltips.regularProgress), findsNothing);

    await tester.tap(_tooltipIcon(CompletionMetricTooltips.masterCompletion));
    await tester.pump();
    expect(
      find.text(CompletionMetricTooltips.masterCompletion),
      findsOneWidget,
    );
  });

  testWidgets('metric tooltip fits compact dark viewport with large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(360, 640),
            textScaler: TextScaler.linear(1.35),
          ),
          child: Scaffold(
            body: CollectorTypeShelfProgressCard(
              stats: _stats(
                completionPercent: 80,
                trackedSeries: 5,
                completedSeriesCount: 4,
                masterCompleteSeriesCount: 2,
                masterEligibleSeriesCount: 2,
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(_tooltipIcon(CompletionMetricTooltips.masterCompletion));
    await tester.pump();

    final tooltipRect = tester.getRect(
      find.text(CompletionMetricTooltips.masterCompletion),
    );
    expect(tooltipRect.left >= 16, isTrue);
    expect(tooltipRect.right <= 344, isTrue);
    expect(tester.takeException(), isNull);
  });
}
