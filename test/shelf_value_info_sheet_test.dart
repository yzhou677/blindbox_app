import 'package:blindbox_app/core/theme/app_theme.dart';
import 'package:blindbox_app/features/collection/insights/application/collection_value_providers.dart';
import 'package:blindbox_app/features/collection/insights/domain/shelf_value_summary.dart';
import 'package:blindbox_app/features/collection/insights/widgets/shelf_value_card.dart';
import 'package:blindbox_app/features/collection/insights/widgets/shelf_value_info_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

ShelfValueSummary _summaryWithEstimates() {
  return const ShelfValueSummary(
    totalValueUsd: 79,
    ownedCount: 2,
    valuedCount: 2,
    unavailableCount: 0,
    topFigures: [],
    seriesBreakdown: [],
    tier: CollectionValueTier.small,
    includesSeriesEstimates: true,
  );
}

Future<void> _pumpShelfValueCard(WidgetTester tester) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        collectionValueProvider.overrideWith(
          (ref) async => _summaryWithEstimates(),
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
}

void main() {
  testWidgets('Shelf Value section renders info icon', (tester) async {
    await _pumpShelfValueCard(tester);

    expect(find.text('Shelf Value'), findsOneWidget);
    expect(find.byIcon(Icons.info_outline), findsOneWidget);
    expect(
      find.bySemanticsLabel(kShelfValueInfoSemanticsLabel),
      findsOneWidget,
    );
  });

  testWidgets('Tap info icon opens bottom sheet', (tester) async {
    await _pumpShelfValueCard(tester);

    await tester.tap(find.byIcon(Icons.info_outline));
    await tester.pumpAndSettle();

    expect(find.text(kShelfValueInfoSheetTitle), findsWidgets);
  });

  testWidgets('Bottom sheet contains how shelf value is calculated title',
      (tester) async {
    await _pumpShelfValueCard(tester);

    await tester.tap(find.byIcon(Icons.info_outline));
    await tester.pumpAndSettle();

    expect(find.text('How shelf value is calculated'), findsWidgets);
  });

  testWidgets('Bottom sheet contains Figure Snapshot section', (tester) async {
    await _pumpShelfValueCard(tester);

    await tester.tap(find.byIcon(Icons.info_outline));
    await tester.pumpAndSettle();

    expect(find.text('Figure Snapshot'), findsOneWidget);
    expect(
      find.text('Based on sales of that exact figure.'),
      findsOneWidget,
    );
  });

  testWidgets('Bottom sheet contains Series Estimate section', (tester) async {
    await _pumpShelfValueCard(tester);

    await tester.tap(find.byIcon(Icons.info_outline));
    await tester.pumpAndSettle();

    expect(find.text('Series Estimate'), findsOneWidget);
    expect(
      find.textContaining(
        'Based on marketplace activity from the same series',
      ),
      findsOneWidget,
    );
  });
}
