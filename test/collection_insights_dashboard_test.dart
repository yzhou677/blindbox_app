import 'package:blindbox_app/core/theme/collectible_motion.dart';
import 'package:blindbox_app/core/theme/collectible_tokens.dart';
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

  testWidgets('collapsed dashboard shows compact glyphs after morph', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          extensions: [CollectibleTokens.forBrightness(Brightness.light)],
        ),
        home: Scaffold(
          body: CollectionInsightsDashboard(
            expanded: false,
            onExpandedChanged: (_) {},
            stats: stats,
          ),
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
    expect(
      find.text(CollectionInsightsDashboardCopy.sectionTitle),
      findsOneWidget,
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
        home: const _ExpandableDashboardHarness(stats: stats),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(CollectionSummaryLabels.wishlist), findsNothing);

    await tester.tap(find.byKey(const Key('collection_insights_dashboard_toggle')));
    await tester.pump();
    await tester.pump(CollectibleMotion.insightsGlanceMorph);
    await tester.pump(CollectibleMotion.sectionReveal);
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
        home: const _ExpandableDashboardHarness(stats: stats),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('collection_insights_compact_glance')));
    await tester.pump();
    await tester.pump(CollectibleMotion.insightsGlanceMorph);
    await tester.pump(CollectibleMotion.sectionReveal);
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text(CollectionSummaryLabels.wishlist), findsOneWidget);
  });
}

class _ExpandableDashboardHarness extends StatefulWidget {
  const _ExpandableDashboardHarness({required this.stats});

  final CollectionAggregateStats stats;

  @override
  State<_ExpandableDashboardHarness> createState() =>
      _ExpandableDashboardHarnessState();
}

class _ExpandableDashboardHarnessState extends State<_ExpandableDashboardHarness> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CollectionInsightsDashboard(
        expanded: _expanded,
        onExpandedChanged: (value) => setState(() => _expanded = value),
        stats: widget.stats,
      ),
    );
  }
}
