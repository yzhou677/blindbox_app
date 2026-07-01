import 'package:blindbox_app/core/theme/app_theme.dart';
import 'package:blindbox_app/core/theme/collectible_tokens.dart';
import 'package:blindbox_app/features/collection/widgets/collection_insights_compact_summary.dart';
import 'package:blindbox_app/features/collection/widgets/collection_insights_dashboard.dart';
import 'package:blindbox_app/features/collection/widgets/collection_summary_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Stress matrix for collapsed Collection Insights compact header.
/// Audit-only — records layout behavior; wrap is informational, not a failure.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const widths = <double>[320, 360, 393, 412];

  final cases = <String, CollectionAggregateStats>{
    'minimal': const CollectionAggregateStats(
      inCollection: 1,
      wantListCount: 0,
      completedSeriesCount: 1,
      masterCompleteSeriesCount: 1,
    ),
    'typical': const CollectionAggregateStats(
      inCollection: 48,
      wantListCount: 0,
      completedSeriesCount: 7,
      masterCompleteSeriesCount: 5,
    ),
    'growing': const CollectionAggregateStats(
      inCollection: 128,
      wantListCount: 0,
      completedSeriesCount: 24,
      masterCompleteSeriesCount: 8,
    ),
    'large': const CollectionAggregateStats(
      inCollection: 342,
      wantListCount: 0,
      completedSeriesCount: 97,
      masterCompleteSeriesCount: 18,
    ),
    'heavy': const CollectionAggregateStats(
      inCollection: 999,
      wantListCount: 0,
      completedSeriesCount: 214,
      masterCompleteSeriesCount: 63,
    ),
    'absurd': const CollectionAggregateStats(
      inCollection: 9999,
      wantListCount: 0,
      completedSeriesCount: 999,
      masterCompleteSeriesCount: 256,
    ),
  };

  for (final width in widths) {
    for (final entry in cases.entries) {
      testWidgets(
        '[$width dp] ${entry.key}',
        (tester) async {
          tester.view.physicalSize = Size(width, 800);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);

          await tester.pumpWidget(
            MaterialApp(
              theme: AppTheme.light().copyWith(
                extensions: [CollectibleTokens.forBrightness(Brightness.light)],
              ),
              home: Scaffold(
                body: CollectionInsightsDashboard(
                  expanded: false,
                  onExpandedChanged: (_) {},
                  stats: entry.value,
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          final glanceFinder = find.byKey(
            const Key('collection_insights_compact_glance'),
          );
          expect(glanceFinder, findsOneWidget);

          final cells = CollectionInsightsCompactSummaryFormat.cells(entry.value);
          final numericTexts = tester
              .widgetList<Text>(
                find.descendant(
                  of: glanceFinder,
                  matching: find.byType(Text),
                ),
              )
              .where((t) => t.data != null)
              .map((t) => t.data!)
              .toList();
          expect(numericTexts, cells);

          final rowHeight = tester.getSize(glanceFinder).height;

          // ignore: avoid_print
          print(
            'STRESS|$width|${entry.key}|cells=${cells.join(' · ')}|'
            'rowH=${rowHeight.toStringAsFixed(1)}',
          );

          expect(rowHeight, lessThanOrEqualTo(52));

          expect(
            tester.takeException(),
            isNull,
            reason: 'collapsed dashboard must not overflow at $width dp',
          );
        },
      );
    }
  }

  testWidgets('numeric layout stays single-row across widths', (tester) async {
    const widths = <double>[320, 360, 393, 412];
    const absurd = CollectionAggregateStats(
      inCollection: 9999,
      wantListCount: 0,
      completedSeriesCount: 999,
      masterCompleteSeriesCount: 256,
    );

    for (final width in widths) {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: CollectionInsightsDashboard(
              expanded: false,
              onExpandedChanged: (_) {},
              stats: absurd,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      tester.takeException();

      final rowHeight = tester.getSize(
        find.byKey(const Key('collection_insights_compact_glance')),
      ).height;
      expect(rowHeight, lessThanOrEqualTo(52), reason: '@${width}dp');
    }
    tester.view.reset();
  });
}
