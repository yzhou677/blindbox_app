import 'package:blindbox_app/core/theme/collectible_motion.dart';
import 'package:blindbox_app/core/theme/collectible_tokens.dart';
import 'package:blindbox_app/features/collection/insights/presentation/collector_type_copy.dart';
import 'package:blindbox_app/features/collection/presentation/collection_summary_editorial.dart';
import 'package:blindbox_app/features/collection/widgets/collection_insights_compact_summary.dart';
import 'package:blindbox_app/features/collection/widgets/collection_insights_dashboard.dart';
import 'package:blindbox_app/features/collection/widgets/collection_summary_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const stats = CollectionAggregateStats(
    inCollection: 48,
    wantListCount: 3,
    completedSeriesCount: 7,
    masterCompleteSeriesCount: 5,
  );

  group('CollectionInsightsCompactSummaryFormat', () {
    test('compact counts omit labels and wishlist', () {
      expect(
        CollectionInsightsCompactSummaryFormat.compactCounts(stats),
        ['48', '7', '5'],
      );
      expect(
        CollectionInsightsCompactSummaryFormat.semanticsLabel(stats),
        '48 Figures, 7 Completed Series, 5 Master Complete',
      );
      expect(
        CollectionInsightsCompactSummaryFormat.semanticsLabel(
          const CollectionAggregateStats(
            inCollection: 48,
            wantListCount: 12,
            completedSeriesCount: 7,
            masterCompleteSeriesCount: 5,
          ),
        ),
        isNot(contains('Wishlist')),
      );
    });
  });

  testWidgets('compact dashboard mutes zero completed and master counts', (
    tester,
  ) async {
    const zeroAchievementStats = CollectionAggregateStats(
      inCollection: 12,
      wantListCount: 0,
      completedSeriesCount: 0,
      masterCompleteSeriesCount: 0,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          extensions: [CollectibleTokens.forBrightness(Brightness.light)],
        ),
        home: Scaffold(
          body: CollectionInsightsDashboard(stats: zeroAchievementStats),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final figureCount = tester.widget<Text>(find.text('12'));
    final zeroCounts = tester.widgetList<Text>(find.text('0')).toList();
    expect(zeroCounts, hasLength(2));

    expect(figureCount.style!.color!.a, closeTo(0.97, 0.06));
    for (final zero in zeroCounts) {
      expect(zero.style!.color!.a, closeTo(0.36, 0.06));
    }
  });

  testWidgets('collapsed dashboard shows compact glyphs at rest', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          extensions: [CollectibleTokens.forBrightness(Brightness.light)],
        ),
        home: Scaffold(
          body: CollectionInsightsDashboard(stats: stats),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('48'), findsOneWidget);
    expect(find.text('7'), findsOneWidget);
    expect(find.text('5'), findsOneWidget);
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    expect(find.text('👑'), findsOneWidget);
    expect(find.text(CollectionSummaryLabels.figures), findsNothing);
    expect(find.text(CollectionSummaryLabels.wishlist), findsNothing);
    // Persistent Summary header communicates expand/collapse.
    expect(
      find.text(CollectionInsightsDashboardCopy.summaryHeader),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.expand_more_rounded), findsOneWidget);
    // Insights navigation lives in the Shelf | Insights segment — not here.
    expect(
      find.text(CollectionInsightsDashboardCopy.sectionTitle),
      findsNothing,
    );
  });

  testWidgets('expanding dashboard reveals full summary section', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          extensions: [CollectibleTokens.forBrightness(Brightness.light)],
        ),
        home: Scaffold(
          body: CollectionInsightsDashboard(stats: stats),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(CollectionSummaryLabels.wishlist), findsNothing);

    await tester.tap(find.byKey(const Key('collection_insights_dashboard_toggle')));
    await tester.pump();
    await tester.pump(CollectibleMotion.insightsDashboardTransition);
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text(CollectionSummaryLabels.wishlist), findsOneWidget);
    expect(find.text(CollectionSummaryLabels.figures), findsOneWidget);
    expect(find.text(CollectionSummaryLabels.seriesComplete), findsOneWidget);
    expect(find.text(CollectionSummaryLabels.masterComplete), findsOneWidget);
  });

  testWidgets('tapping compact glance row expands dashboard', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          extensions: [CollectibleTokens.forBrightness(Brightness.light)],
        ),
        home: Scaffold(
          body: CollectionInsightsDashboard(stats: stats),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('collection_insights_compact_glance')));
    await tester.pump();
    await tester.pump(CollectibleMotion.insightsDashboardTransition);
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text(CollectionSummaryLabels.wishlist), findsOneWidget);
  });

  testWidgets('expand and collapse transitions do not overflow layout', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          extensions: [CollectibleTokens.forBrightness(Brightness.light)],
        ),
        home: Scaffold(
          body: CollectionInsightsDashboard(
            stats: stats,
            shelfMoodLine: 'Your collection is quietly taking shape.',
            memoryWhisper: 'A gentle milestone on the shelf.',
            collectorTypeName: 'Curator',
            onInsightsTap: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    Future<void> pumpTransitionFrames() async {
      var elapsed = 0;
      const step = 16;
      final total =
          CollectibleMotion.insightsDashboardTransition.inMilliseconds;
      while (elapsed <= total) {
        await tester.pump(const Duration(milliseconds: step));
        expect(tester.takeException(), isNull);
        elapsed += step;
      }
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }

    await tester.tap(find.byKey(const Key('collection_insights_dashboard_toggle')));
    await tester.pump();
    await pumpTransitionFrames();

    await tester.tap(find.byKey(const Key('collection_insights_dashboard_toggle')));
    await tester.pump();
    await pumpTransitionFrames();
  });

  testWidgets(
    'expanded height remeasures after dashboard inputs grow asynchronously',
    (tester) async {
      const moodLine = 'Your collection is quietly taking shape.';
      const whisper = 'A gentle milestone on the shelf.';
      const collectorType = 'Curator';

      Widget buildBody({
        required String? shelfMoodLine,
        required String? memoryWhisper,
        required String? collectorTypeName,
      }) {
        return MaterialApp(
          theme: ThemeData(
            extensions: [CollectibleTokens.forBrightness(Brightness.light)],
          ),
          home: Scaffold(
            body: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                KeyedSubtree(
                  key: const Key('collection_insights_dashboard_slot'),
                  child: CollectionInsightsDashboard(
                    stats: stats,
                    shelfMoodLine: shelfMoodLine,
                    memoryWhisper: memoryWhisper,
                    collectorTypeName: collectorTypeName,
                    onInsightsTap: () {},
                  ),
                ),
                const Text(
                  'My collection',
                  key: Key('my_collection_header'),
                ),
              ],
            ),
          ),
        );
      }

      await tester.pumpWidget(
        buildBody(
          shelfMoodLine: null,
          memoryWhisper: null,
          collectorTypeName: null,
        ),
      );
      await tester.pumpAndSettle();

      await tester.pumpWidget(
        buildBody(
          shelfMoodLine: moodLine,
          memoryWhisper: whisper,
          collectorTypeName: collectorType,
        ),
      );
      await tester.pump();
      await tester.pump();

      await tester.tap(
        find.byKey(const Key('collection_insights_dashboard_toggle')),
      );
      await tester.pump();
      await tester.pump(CollectibleMotion.insightsDashboardTransition);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text(moodLine), findsOneWidget);
      expect(find.text(whisper), findsOneWidget);
      expect(
        find.text(
          '${CollectorTypeCopy.entryRevealedPrefix}: $collectorType',
        ),
        findsOneWidget,
      );

      final slotRect = tester.getRect(
        find.byKey(const Key('collection_insights_dashboard_slot')),
      );
      final moodRect = tester.getRect(find.text(moodLine));
      final headerRect = tester.getRect(
        find.byKey(const Key('my_collection_header')),
      );

      expect(
        slotRect.bottom,
        greaterThanOrEqualTo(moodRect.bottom - 1),
        reason: 'editorial mood line must not be clipped by dashboard slot',
      );
      expect(
        headerRect.top,
        greaterThanOrEqualTo(slotRect.bottom - 1),
        reason: 'My collection must sit below the full expanded dashboard',
      );
    },
  );
}
