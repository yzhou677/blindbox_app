import 'package:blindbox_app/features/catalog/presentation/catalog_series_search_rows.dart';
import 'package:blindbox_app/features/catalog/widgets/catalog_series_search_row_card.dart';
import 'package:blindbox_app/features/collection/presentation/collection_series_shelf_cta_presentation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'catalog row shows outline and filled wishlist heart when addable',
    (tester) async {
      var toggles = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CatalogSeriesSearchRowCard(
              row: _row,
              shelfCta: _addable,
              isWishlisted: false,
              onWishlistPressed: () => toggles++,
              onOpenPreview: () {},
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.favorite_border_rounded), findsOneWidget);
      await tester.tap(find.byIcon(Icons.favorite_border_rounded));
      expect(toggles, 1);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CatalogSeriesSearchRowCard(
              row: _row,
              shelfCta: _addable,
              isWishlisted: true,
              onWishlistPressed: () => toggles++,
              onOpenPreview: () {},
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);
    },
  );

  testWidgets('catalog row hides wishlist heart when series is in collection', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CatalogSeriesSearchRowCard(
            row: _row,
            shelfCta: _owned,
            isWishlisted: true,
            onWishlistPressed: () {},
            onOpenPreview: () {},
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.favorite_rounded), findsNothing);
    expect(find.byIcon(Icons.favorite_border_rounded), findsNothing);
  });
}

const _row = CatalogSeriesSearchRow(
  seriesId: 'catalog-series',
  seriesTitle: 'Catalog Series',
  coverImageKey: '',
  summaryLine: '12 figures',
  ipLine: 'THE MONSTERS',
  brand: 'POP MART',
  taxonomyBrandId: 'pop_mart',
  taxonomyIpId: 'the_monsters',
  hasAnySecret: false,
);

const _addable = CollectionSeriesShelfCtaPresentation(
  visualState: OwnershipShelfCtaVisualState.addable,
  label: 'Add',
  icon: Icons.add_rounded,
  enabled: true,
  semanticsLabel: 'Add to collection',
  usePrimaryTint: true,
);

const _owned = CollectionSeriesShelfCtaPresentation(
  visualState: OwnershipShelfCtaVisualState.owned,
  label: 'In collection',
  icon: Icons.check_rounded,
  enabled: false,
  semanticsLabel: 'Already in your collection',
  usePrimaryTint: false,
);
