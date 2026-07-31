import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/collection/presentation/collection_shelf_brand_facets.dart';
import 'package:blindbox_app/features/collection/presentation/collection_shelf_ip_facets.dart';
import 'package:blindbox_app/features/collection/presentation/collection_wishlist_browse.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late CollectionSnapshot snap;
  late List<WishlistedFigureRow> figures;

  setUp(() {
    snap = _snapshot();
    figures = wishlistedFigureRows(snap);
  });

  List<String> ipIds({required String brandFilterId}) {
    return buildWishlistIpFilterOptions(
      snap.seriesWishlist,
      figures,
      brandFilterId: brandFilterId,
    ).map((o) => o.id).toList();
  }

  group('Wishlist Brand → IP option dependency', () {
    test('All Brands shows IPs across brands', () {
      final ids = ipIds(brandFilterId: collectionAnyBrandFilterId);
      expect(ids.first, collectionAnyIpFilterId);
      expect(
        ids,
        containsAll([
          normalizeCollectionFacetFilterKey('Molly'),
          normalizeCollectionFacetFilterKey('Panda Roll'),
          normalizeCollectionFacetFilterKey('THE MONSTERS'),
          normalizeCollectionFacetFilterKey('SKULLPANDA'),
          normalizeCollectionFacetFilterKey('Dimoo'),
        ]),
      );
    });

    test('Selecting POP MART shows only POP MART IPs', () {
      final popMart = normalizeCollectionFacetFilterKey('POP MART');
      final ids = ipIds(brandFilterId: popMart);
      expect(ids, [
        collectionAnyIpFilterId,
        normalizeCollectionFacetFilterKey('Molly'),
        normalizeCollectionFacetFilterKey('THE MONSTERS'),
        normalizeCollectionFacetFilterKey('SKULLPANDA'),
      ]);
      expect(ids, isNot(contains(normalizeCollectionFacetFilterKey('Panda Roll'))));
      expect(ids, isNot(contains(normalizeCollectionFacetFilterKey('Dimoo'))));
    });

    test('Switching to another Brand replaces the IP options', () {
      final popMartIps = ipIds(
        brandFilterId: normalizeCollectionFacetFilterKey('POP MART'),
      );
      final toys52Ips = ipIds(
        brandFilterId: normalizeCollectionFacetFilterKey('52TOYS'),
      );

      expect(
        popMartIps,
        contains(normalizeCollectionFacetFilterKey('Molly')),
      );
      expect(
        toys52Ips,
        isNot(contains(normalizeCollectionFacetFilterKey('Molly'))),
      );
      expect(
        toys52Ips,
        [
          collectionAnyIpFilterId,
          normalizeCollectionFacetFilterKey('Panda Roll'),
        ],
      );
    });

    test('Invalid selected IP resets to All IPs when Brand changes', () {
      final molly = normalizeCollectionFacetFilterKey('Molly');
      final toys52 = normalizeCollectionFacetFilterKey('52TOYS');
      final optionsAfterBrandChange = buildWishlistIpFilterOptions(
        snap.seriesWishlist,
        figures,
        brandFilterId: toys52,
      );
      final resolved = resolveWishlistFacetSelection(
        selectedId: molly,
        optionIds: optionsAfterBrandChange.map((o) => o.id),
        anyId: collectionAnyIpFilterId,
      );
      expect(resolved, collectionAnyIpFilterId);
    });

    test('Valid selected IP remains selected when Brand keeps it', () {
      final monsters = normalizeCollectionFacetFilterKey('THE MONSTERS');
      final popMart = normalizeCollectionFacetFilterKey('POP MART');
      // Molly is POP MART-only; THE MONSTERS stays available under POP MART.
      final options = buildWishlistIpFilterOptions(
        snap.seriesWishlist,
        figures,
        brandFilterId: popMart,
      );
      final resolved = resolveWishlistFacetSelection(
        selectedId: monsters,
        optionIds: options.map((o) => o.id),
        anyId: collectionAnyIpFilterId,
      );
      expect(resolved, monsters);
    });

    test('Empty Brand/IP combinations yield All IPs only', () {
      final unknownBrand = normalizeCollectionFacetFilterKey('NO SUCH BRAND');
      expect(ipIds(brandFilterId: unknownBrand), [collectionAnyIpFilterId]);

      expect(
        filterWishlistSeries(
          series: snap.seriesWishlist,
          query: '',
          brandFilterId: unknownBrand,
          ipFilterId: collectionAnyIpFilterId,
        ),
        isEmpty,
      );
      expect(
        filterWishlistFigures(
          figures: figures,
          query: '',
          brandFilterId: unknownBrand,
          ipFilterId: collectionAnyIpFilterId,
        ),
        isEmpty,
      );
    });

    test(
      'IP options come from Brand-scoped source, not Brand+IP results',
      () {
        final popMart = normalizeCollectionFacetFilterKey('POP MART');
        final molly = normalizeCollectionFacetFilterKey('Molly');

        // Even if results are narrowed to Molly only, IP chips still list
        // every POP MART IP present in Wishlist source under that Brand.
        final filteredSeries = filterWishlistSeries(
          series: snap.seriesWishlist,
          query: '',
          brandFilterId: popMart,
          ipFilterId: molly,
        );
        expect(filteredSeries.map((s) => s.name), ['Sweet Bean']);

        final ipFromSource = ipIds(brandFilterId: popMart);
        expect(
          ipFromSource,
          containsAll([
            normalizeCollectionFacetFilterKey('Molly'),
            normalizeCollectionFacetFilterKey('THE MONSTERS'),
            normalizeCollectionFacetFilterKey('SKULLPANDA'),
          ]),
        );
      },
    );
  });

  group('Wishlist Series and Figures filter under Brand → IP', () {
    test('Series and Figures both filter correctly for Brand then IP', () {
      final popMart = normalizeCollectionFacetFilterKey('POP MART');
      final monsters = normalizeCollectionFacetFilterKey('THE MONSTERS');

      expect(
        filterWishlistSeries(
          series: snap.seriesWishlist,
          query: '',
          brandFilterId: popMart,
          ipFilterId: collectionAnyIpFilterId,
        ).map((s) => s.name),
        ['Sweet Bean'],
      );
      expect(
        filterWishlistFigures(
          figures: figures,
          query: '',
          brandFilterId: popMart,
          ipFilterId: collectionAnyIpFilterId,
        ).map((row) => row.figure.name).toSet(),
        {'Soymilk', 'Quilt'},
      );

      expect(
        filterWishlistSeries(
          series: snap.seriesWishlist,
          query: '',
          brandFilterId: popMart,
          ipFilterId: monsters,
        ),
        isEmpty,
      );
      expect(
        filterWishlistFigures(
          figures: figures,
          query: '',
          brandFilterId: popMart,
          ipFilterId: monsters,
        ).map((row) => row.figure.name),
        ['Soymilk'],
      );
    });

    test('52TOYS Brand scopes Series; TOP TOY scopes Figure Wishlist', () {
      final toys52 = normalizeCollectionFacetFilterKey('52TOYS');
      final topToy = normalizeCollectionFacetFilterKey('TOP TOY');
      final dimoo = normalizeCollectionFacetFilterKey('Dimoo');

      expect(
        filterWishlistSeries(
          series: snap.seriesWishlist,
          query: '',
          brandFilterId: toys52,
          ipFilterId: collectionAnyIpFilterId,
        ).map((s) => s.name),
        ['Ancient Castle'],
      );
      expect(
        filterWishlistFigures(
          figures: figures,
          query: '',
          brandFilterId: toys52,
          ipFilterId: collectionAnyIpFilterId,
        ),
        isEmpty,
      );

      expect(
        filterWishlistSeries(
          series: snap.seriesWishlist,
          query: '',
          brandFilterId: topToy,
          ipFilterId: collectionAnyIpFilterId,
        ),
        isEmpty,
      );
      expect(
        filterWishlistFigures(
          figures: figures,
          query: '',
          brandFilterId: topToy,
          ipFilterId: dimoo,
        ).map((row) => row.figure.name),
        ['Pilot'],
      );

      expect(
        ipIds(brandFilterId: topToy),
        [collectionAnyIpFilterId, dimoo],
      );
    });
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
  final dimooOnlyFigure = ShelfSeries(
    id: 'series-dimoo-fig',
    name: 'Dimoo World',
    brand: 'TOP TOY',
    ipName: 'Dimoo',
    figures: const [
      ShelfFigure(
        id: 'fig-dimoo',
        seriesId: 'series-dimoo-fig',
        name: 'Pilot',
        rarity: 'Regular',
        isSecret: false,
      ),
    ],
    shelfAccent: const Color(0xFFE8DEF5),
  );

  return CollectionSnapshot(
    shelfSeries: [monsters, skullpanda, dimooOnlyFigure],
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
      'fig-dimoo': TrackedFigure(
        figureId: 'fig-dimoo',
        state: FigureCollectionState.wishlist,
        updatedAtMicros: 5,
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
