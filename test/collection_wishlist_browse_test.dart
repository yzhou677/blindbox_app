import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/collection/presentation/collection_shelf_brand_facets.dart';
import 'package:blindbox_app/features/collection/presentation/collection_shelf_ip_facets.dart';
import 'package:blindbox_app/features/collection/presentation/collection_wishlist_browse.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'wishlist browse searches series and figures by name, brand, and IP',
    () {
      final snap = _snapshot();
      final figures = wishlistedFigureRows(snap);

      expect(
        filterWishlistSeries(
          series: snap.seriesWishlist,
          query: 'molly',
          brandFilterId: collectionAnyBrandFilterId,
          ipFilterId: collectionAnyIpFilterId,
        ).map((s) => s.name),
        ['Sweet Bean'],
      );
      expect(
        filterWishlistFigures(
          figures: figures,
          query: 'monsters',
          brandFilterId: collectionAnyBrandFilterId,
          ipFilterId: collectionAnyIpFilterId,
        ).map((row) => row.figure.name),
        ['Soymilk'],
      );
    },
  );

  test('wishlist browse filters independently by Brand and IP', () {
    final snap = _snapshot();
    final figures = wishlistedFigureRows(snap);

    expect(
      filterWishlistSeries(
        series: snap.seriesWishlist,
        query: '',
        brandFilterId: normalizeCollectionFacetFilterKey('POP MART'),
        ipFilterId: normalizeCollectionFacetFilterKey('Molly'),
      ).map((s) => s.name),
      ['Sweet Bean'],
    );
    expect(
      filterWishlistFigures(
        figures: figures,
        query: '',
        brandFilterId: normalizeCollectionFacetFilterKey('POP MART'),
        ipFilterId: normalizeCollectionFacetFilterKey('THE MONSTERS'),
      ).map((row) => row.figure.name),
      ['Soymilk'],
    );
  });

  test('wishlist browse sorts by recently added and alphabetical', () {
    final snap = _snapshot();
    final figures = wishlistedFigureRows(snap);

    expect(
      sortWishlistSeries(
        snap.seriesWishlist,
        CollectionWishlistSort.recentlyAdded,
      ).map((s) => s.name),
      ['Sweet Bean', 'Ancient Castle'],
    );
    expect(
      sortWishlistSeries(
        snap.seriesWishlist,
        CollectionWishlistSort.alphabetical,
      ).map((s) => s.name),
      ['Ancient Castle', 'Sweet Bean'],
    );
    expect(
      sortWishlistFigures(
        figures,
        CollectionWishlistSort.recentlyAdded,
      ).map((row) => row.figure.name),
      ['Soymilk', 'Quilt'],
    );
  });
}

CollectionSnapshot _snapshot() {
  final monsters = ShelfSeries(
    id: 'series-monsters',
    name: 'Exciting Macaron',
    brand: 'POP MART',
    ipName: 'THE MONSTERS',
    figures: const [
      ShelfFigure(
        id: 'fig-labubu',
        seriesId: 'series-monsters',
        name: 'Soymilk',
        rarity: 'Regular',
        isSecret: false,
      ),
    ],
    shelfAccent: const Color(0xFFE8DEF5),
  );
  final skullpanda = ShelfSeries(
    id: 'series-skull',
    name: 'The Warmth',
    brand: 'POP MART',
    ipName: 'SKULLPANDA',
    figures: const [
      ShelfFigure(
        id: 'fig-quilt',
        seriesId: 'series-skull',
        name: 'Quilt',
        rarity: 'Regular',
        isSecret: false,
      ),
    ],
    shelfAccent: const Color(0xFFE8DEF5),
  );

  return CollectionSnapshot(
    shelfSeries: [monsters, skullpanda],
    figureStates: const {
      'fig-labubu': TrackedFigure(
        figureId: 'fig-labubu',
        state: FigureCollectionState.wishlist,
        updatedAtMicros: 20,
      ),
      'fig-quilt': TrackedFigure(
        figureId: 'fig-quilt',
        state: FigureCollectionState.wishlist,
        updatedAtMicros: 10,
      ),
    },
    seriesWishlist: const [
      WishlistedCatalogSeries(
        catalogSeriesId: 'ancient-castle',
        name: 'Ancient Castle',
        brand: '52TOYS',
        ipName: 'Panda Roll',
        imageKey: 'ancient-castle',
        addedAtMicros: 1,
      ),
      WishlistedCatalogSeries(
        catalogSeriesId: 'sweet-bean',
        name: 'Sweet Bean',
        brand: 'POP MART',
        ipName: 'Molly',
        imageKey: 'sweet-bean',
        addedAtMicros: 2,
      ),
    ],
  );
}
