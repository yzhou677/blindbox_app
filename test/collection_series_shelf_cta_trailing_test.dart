import 'package:blindbox_app/features/collection/application/collection_series_identity.dart';
import 'package:blindbox_app/features/collection/presentation/collection_series_shelf_cta_presentation.dart';
import 'package:blindbox_app/features/collection/widgets/collection_series_shelf_cta_trailing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('owned presentation shows In collection not Add', (tester) async {
    const match = CollectionSeriesOwnershipMatch.owned(
      kind: CollectionSeriesOwnershipMatchKind.exactCatalogTemplate,
      matchedSeriesId: 's1',
      matchedCatalogTemplateId: 'series_a',
    );
    final cta = CollectionSeriesShelfCtaPresentation.fromOwnership(
      match,
      layout: CollectionSeriesShelfCtaLayout.compactTrailing,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CollectionSeriesShelfCtaTrailing(presentation: cta),
        ),
      ),
    );

    expect(find.text('In collection'), findsOneWidget);
    expect(find.text('Add'), findsNothing);
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    expect(find.byIcon(Icons.add_rounded), findsNothing);
  });

  testWidgets('disabled owned chip does not accept taps', (tester) async {
    var tapped = false;
    const match = CollectionSeriesOwnershipMatch.owned(
      kind: CollectionSeriesOwnershipMatchKind.exactCatalogTemplate,
      matchedSeriesId: 's1',
      matchedCatalogTemplateId: 'series_a',
    );
    final cta = CollectionSeriesShelfCtaPresentation.fromOwnership(
      match,
      layout: CollectionSeriesShelfCtaLayout.compactTrailing,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CollectionSeriesShelfCtaTrailing(
            presentation: cta,
            onPressed: () => tapped = true,
          ),
        ),
      ),
    );

    await tester.tap(find.byType(CollectionSeriesShelfCtaTrailing));
    await tester.pump();
    expect(tapped, isFalse);
  });
}
