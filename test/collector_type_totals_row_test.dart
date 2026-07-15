import 'package:blindbox_app/features/collection/insights/domain/collector_type_stats.dart';
import 'package:blindbox_app/features/collection/insights/presentation/collector_type_copy.dart';
import 'package:blindbox_app/features/collection/insights/widgets/collector_type_totals_row.dart';
import 'package:blindbox_app/features/collection/presentation/completion_metric_tooltips.dart';
import 'package:blindbox_app/features/collection/presentation/collection_vocabulary.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Finder _tooltipIcon(String message) =>
    find.byKey(ValueKey<String>('info-tooltip-$message'));

void main() {
  testWidgets('at-a-glance shows achievement-focused collector snapshot', (
    tester,
  ) async {
    const stats = CollectorTypeStats(
      totalOwned: 41,
      totalWishlist: 0,
      trackedSeries: 5,
      completedSeriesCount: 5,
      masterCompleteSeriesCount: 2,
      masterEligibleSeriesCount: 0,
      completionPercent: 72,
      secretOwned: 5,
      secretSlots: 8,
      brandBreakdown: {},
      topSeries: [],
      customSeriesRatio: 0,
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: CollectorTypeTotalsRow(stats: stats)),
      ),
    );

    expect(find.text('41'), findsOneWidget);
    expect(find.text(CollectorTypeCopy.atAGlanceOwnedFigures), findsOneWidget);
    expect(find.text('5'), findsNWidgets(2));
    expect(
      find.text(CollectorTypeCopy.atAGlanceCompletedSeries),
      findsOneWidget,
    );
    expect(find.text('2'), findsOneWidget);
    expect(
      find.text(CollectorTypeCopy.atAGlanceMasterComplete),
      findsOneWidget,
    );
    expect(
      find.text(CollectorTypeCopy.atAGlanceSecretsCollected),
      findsOneWidget,
    );
    expect(
      _tooltipIcon(CompletionMetricTooltips.completedSeries),
      findsOneWidget,
    );
    expect(
      _tooltipIcon(CompletionMetricTooltips.masterComplete),
      findsOneWidget,
    );
    expect(
      _tooltipIcon(CompletionMetricTooltips.secretsCollected),
      findsOneWidget,
    );

    // Distinct from Collection Summary wishlist row.
    expect(find.text(CollectionVocabulary.wishlistedFigures), findsNothing);
    expect(find.text(CollectionVocabulary.wishlist), findsNothing);
    expect(
      find.textContaining(CollectionVocabulary.shelfProgress),
      findsNothing,
    );
  });

  testWidgets('at-a-glance metric tooltips open', (tester) async {
    const stats = CollectorTypeStats(
      totalOwned: 41,
      totalWishlist: 0,
      trackedSeries: 5,
      completedSeriesCount: 5,
      masterCompleteSeriesCount: 2,
      masterEligibleSeriesCount: 0,
      completionPercent: 72,
      secretOwned: 5,
      secretSlots: 8,
      brandBreakdown: {},
      topSeries: [],
      customSeriesRatio: 0,
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: CollectorTypeTotalsRow(stats: stats)),
      ),
    );

    await tester.tap(_tooltipIcon(CompletionMetricTooltips.completedSeries));
    await tester.pump();
    expect(find.text(CompletionMetricTooltips.completedSeries), findsOneWidget);

    await tester.tap(_tooltipIcon(CompletionMetricTooltips.masterComplete));
    await tester.pump();
    expect(find.text(CompletionMetricTooltips.completedSeries), findsNothing);
    expect(find.text(CompletionMetricTooltips.masterComplete), findsOneWidget);

    await tester.tap(_tooltipIcon(CompletionMetricTooltips.secretsCollected));
    await tester.pump();
    expect(find.text(CompletionMetricTooltips.masterComplete), findsNothing);
    expect(
      find.text(CompletionMetricTooltips.secretsCollected),
      findsOneWidget,
    );

    await tester.tapAt(const Offset(1, 1));
    await tester.pumpAndSettle();
    expect(find.text(CompletionMetricTooltips.secretsCollected), findsNothing);
  });
}
