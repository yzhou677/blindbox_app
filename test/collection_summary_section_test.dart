import 'package:blindbox_app/core/theme/collectible_tokens.dart';
import 'package:blindbox_app/features/collection/presentation/completion_metric_tooltips.dart';
import 'package:blindbox_app/features/collection/presentation/collection_summary_editorial.dart';
import 'package:blindbox_app/features/collection/widgets/collection_summary_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Finder _tooltipIcon(String message) =>
    find.byKey(ValueKey<String>('info-tooltip-$message'));

void main() {
  testWidgets('summary shows figure and series metric labels', (tester) async {
    tester.view.physicalSize = const Size(390, 500);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    const stats = CollectionAggregateStats(
      inCollection: 11,
      wantListCount: 0,
      completedSeriesCount: 3,
      masterCompleteSeriesCount: 1,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          extensions: [CollectibleTokens.forBrightness(Brightness.light)],
        ),
        home: Scaffold(
          body: CollectionSummarySection(
            stats: stats,
            shelfMoodLine: 'Your collection has in-progress series.',
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text(CollectionSummaryLabels.figures), findsOneWidget);
    expect(find.text(CollectionSummaryLabels.wishlist), findsOneWidget);
    expect(find.text(CollectionSummaryLabels.seriesComplete), findsOneWidget);
    expect(find.text(CollectionSummaryLabels.masterComplete), findsOneWidget);
    expect(
      _tooltipIcon(CompletionMetricTooltips.completedSeries),
      findsOneWidget,
    );
    expect(find.text('In collection'), findsNothing);
    expect(find.text('Master'), findsNothing);
  });

  testWidgets('summary always shows stable 2x2 grid with muted zero row', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 500);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    const stats = CollectionAggregateStats(
      inCollection: 2,
      wantListCount: 1,
      completedSeriesCount: 0,
      masterCompleteSeriesCount: 0,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          extensions: [CollectibleTokens.forBrightness(Brightness.light)],
        ),
        home: const Scaffold(body: CollectionSummarySection(stats: stats)),
      ),
    );
    await tester.pump();

    expect(find.text(CollectionSummaryLabels.seriesComplete), findsOneWidget);
    expect(find.text(CollectionSummaryLabels.masterComplete), findsOneWidget);
    expect(find.text('0'), findsNWidgets(2));
  });

  testWidgets('summary metric tooltip does not trigger card tap', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 500);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    var taps = 0;
    const stats = CollectionAggregateStats(
      inCollection: 11,
      wantListCount: 0,
      completedSeriesCount: 3,
      masterCompleteSeriesCount: 1,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          extensions: [CollectibleTokens.forBrightness(Brightness.light)],
        ),
        home: Scaffold(
          body: CollectionSummarySection(
            stats: stats,
            onSummaryCardTap: () => taps++,
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(_tooltipIcon(CompletionMetricTooltips.completedSeries));
    await tester.pump();

    expect(taps, 0);
    expect(find.text(CompletionMetricTooltips.completedSeries), findsOneWidget);

    await tester.tapAt(const Offset(1, 1));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('collection_summary_stats_card')));
    await tester.pump();

    expect(taps, 1);
  });
}
