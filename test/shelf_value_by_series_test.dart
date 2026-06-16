import 'package:blindbox_app/core/theme/app_theme.dart';
import 'package:blindbox_app/features/collection/insights/application/collection_value_providers.dart';
import 'package:blindbox_app/features/collection/insights/domain/shelf_value_summary.dart';
import 'package:blindbox_app/features/collection/insights/widgets/shelf_value_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

ShelfValueSummary _summaryWithSeries({
  required bool hasSeriesEstimates,
}) {
  return ShelfValueSummary(
    totalValueUsd: 183,
    ownedCount: 2,
    valuedCount: 2,
    unavailableCount: 0,
    topFigures: const [],
    seriesBreakdown: [
      SeriesValueEntry(
        seriesId: 'series_big_into_energy',
        seriesName: 'THE MONSTERS Big Into Energy',
        totalValueUsd: 183,
        valuedFigureCount: 2,
        ownedFigureCount: 2,
        hasSeriesEstimates: hasSeriesEstimates,
      ),
    ],
    tier: CollectionValueTier.small,
    includesSeriesEstimates: hasSeriesEstimates,
  );
}

Future<void> _pumpBySeriesRow(
  WidgetTester tester, {
  required bool hasSeriesEstimates,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        collectionValueProvider.overrideWith(
          (ref) async => _summaryWithSeries(
            hasSeriesEstimates: hasSeriesEstimates,
          ),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(
          body: SingleChildScrollView(
            child: ShelfValueCard(),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();

  await tester.tap(find.text('By Series'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('By Series row shows plain total for figure snapshots only',
      (tester) async {
    await _pumpBySeriesRow(tester, hasSeriesEstimates: false);

    expect(find.text(r'~$183'), findsOneWidget);
    expect(find.text(r'$183'), findsOneWidget);
    expect(find.text('THE MONSTERS Big Into Energy'), findsOneWidget);
  });

  testWidgets('By Series row prefixes tilde when series estimates contributed',
      (tester) async {
    await _pumpBySeriesRow(tester, hasSeriesEstimates: true);

    expect(find.text(r'~$183'), findsNWidgets(2));
    expect(find.text(r'$183'), findsNothing);
    expect(find.text('THE MONSTERS Big Into Energy'), findsOneWidget);
  });
}
