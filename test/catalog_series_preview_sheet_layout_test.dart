import 'package:blindbox_app/features/collectible_relationship/application/collectible_relationship_providers.dart';
import 'package:blindbox_app/features/collection/application/collection_series_identity.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/collection/presentation/collection_series_shelf_cta_presentation.dart';
import 'package:blindbox_app/features/collection/widgets/catalog_series_preview_sheet.dart';
import 'package:blindbox_app/shared/widgets/collectible_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

CatalogSeries _series({int figureCount = 24}) {
  return CatalogSeries(
    templateId: 'cry_me_an_ocean',
    name: 'Cry Me an Ocean Series',
    brand: 'POP MART',
    ipName: 'Crybaby',
    figures: [
      for (var i = 0; i < figureCount; i++)
        CatalogFigure(
          templateFigureId: 'fig_$i',
          catalogSeriesTemplateId: 'cry_me_an_ocean',
          name: 'Figure $i',
          rarity: i == 0 ? '1:144' : 'Regular',
          isSecret: i == 0,
        ),
    ],
    shelfAccent: const Color(0xFFE8DEF5),
  );
}

Future<void> _pumpPreview(
  WidgetTester tester, {
  required CatalogSeries series,
  required CollectionSeriesShelfCtaPresentation shelfCta,
  double bottomInset = 0,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        relationshipHintForCatalogSeriesProvider.overrideWith((ref, _) => null),
      ],
      child: MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
            size: const Size(420, 820),
            padding: EdgeInsets.only(bottom: bottomInset),
          ),
          child: Scaffold(
            body: Center(
              child: SizedBox(
                key: const ValueKey<String>('preview-host'),
                width: 400,
                height: 720,
                child: CollectibleSheetScope(
                  scrollController: ScrollController(),
                  child: CatalogSeriesPreviewSheet(
                    series: series,
                    shelfCta: shelfCta,
                    onAdd: () {},
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  final addableCta = CollectionSeriesShelfCtaPresentation.fromOwnership(
    const CollectionSeriesOwnershipMatch.notOwned(),
    layout: CollectionSeriesShelfCtaLayout.previewSticky,
  );

  testWidgets('sticky CTA remains visible while content scrolls', (tester) async {
    await _pumpPreview(tester, series: _series(), shelfCta: addableCta);

    expect(find.byKey(const ValueKey<String>('catalog-preview-add-cta')), findsOneWidget);
    expect(find.text('Cry Me an Ocean Series'), findsOneWidget);

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -520));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey<String>('catalog-preview-add-cta')), findsOneWidget);
    expect(find.text('Cry Me an Ocean Series'), findsOneWidget);
  });

  testWidgets('figure content remains accessible with sticky CTA', (tester) async {
    await _pumpPreview(
      tester,
      series: _series(figureCount: 28),
      shelfCta: addableCta,
    );

    await tester.scrollUntilVisible(
      find.text('Figure 27'),
      360,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('Figure 27'), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('catalog-preview-add-cta')), findsOneWidget);
  });

  testWidgets('owned preview shows disabled In collection CTA', (tester) async {
    final ownedCta = CollectionSeriesShelfCtaPresentation.fromOwnership(
      const CollectionSeriesOwnershipMatch.owned(
        kind: CollectionSeriesOwnershipMatchKind.canonicalBrandSeries,
        matchedSeriesId: 'user-row',
      ),
      layout: CollectionSeriesShelfCtaLayout.previewSticky,
    );
    await _pumpPreview(
      tester,
      series: _series(figureCount: 4),
      shelfCta: ownedCta,
    );

    expect(
      find.byKey(const ValueKey<String>('catalog-preview-owned-cta')),
      findsOneWidget,
    );
    expect(find.text('In collection'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('catalog-preview-add-cta')),
      findsNothing,
    );
  });

  testWidgets('sticky CTA respects safe-area bottom inset', (tester) async {
    await _pumpPreview(
      tester,
      series: _series(figureCount: 8),
      shelfCta: addableCta,
      bottomInset: 32,
    );

    final host = tester.getRect(find.byKey(const ValueKey<String>('preview-host')));
    final cta = tester.getRect(find.byKey(const ValueKey<String>('catalog-preview-add-cta')));

    expect(host.bottom - cta.bottom, greaterThanOrEqualTo(32));
  });
}
