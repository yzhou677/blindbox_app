import 'package:blindbox_app/core/search/search_matcher.dart';
import 'package:blindbox_app/core/search/search_normalizer.dart';
import 'package:blindbox_app/core/search/search_placeholders.dart';
import 'package:blindbox_app/core/search/search_tokenizer.dart';
import 'package:blindbox_app/features/catalog/catalog_seed_loader.dart';
import 'package:blindbox_app/features/catalog/search/catalog_search_history.dart';
import 'package:blindbox_app/features/catalog/search/catalog_search_service.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/collection/presentation/collection_shelf_browse.dart';
import 'package:blindbox_app/features/market/catalog/market_listing_filters.dart';
import 'package:blindbox_app/models/collectible.dart';
import 'package:blindbox_app/models/market_listing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SearchNormalizer', () {
    test('lowercases and collapses whitespace', () {
      expect(SearchNormalizer.normalize('  Macaron  '), 'macaron');
    });

    test('folds separator characters into spaces', () {
      expect(
        SearchNormalizer.normalize('THE MONSTERS × HELLO KITTY'),
        'the monsters hello kitty',
      );
      expect(
        SearchNormalizer.normalize('Hirono Boundary — Test'),
        'hirono boundary test',
      );
      expect(SearchNormalizer.normalize('pop_mart/sku'), 'pop mart sku');
    });
  });

  group('SearchTokenizer', () {
    test('splits normalized query on spaces', () {
      expect(
        SearchTokenizer.tokenize('the monsters hello kitty'),
        ['the', 'monsters', 'hello', 'kitty'],
      );
    });

    test('empty raw query yields no tokens', () {
      expect(SearchTokenizer.tokenize('   '), isEmpty);
    });
  });

  group('SearchMatcher', () {
    test('token AND requires every token in haystack', () {
      const haystack = 'the monsters hello kitty vinyl';
      expect(
        SearchMatcher.allTokensMatch(haystack, ['hello', 'kitty']),
        isTrue,
      );
      expect(
        SearchMatcher.allTokensMatch(haystack, ['football', 'kitty']),
        isFalse,
      );
    });
  });

  group('CatalogSearchService token matching', () {
    late CatalogSeedBundle bundle;

    setUp(() {
      bundle = CatalogSeedBundle(
        brands: parseCatalogBrandsJson(r'''[
          {"id": "pop_mart", "displayName": "POP MART", "aliases": ["POPMART"]}
        ]'''),
        ips: parseCatalogIpsJson(r'''[
          {"id": "the_monsters", "brandId": "pop_mart", "displayName": "THE MONSTERS",
           "aliases": ["Labubu"]},
          {"id": "hello_kitty", "brandId": "pop_mart", "displayName": "HELLO KITTY", "aliases": []}
        ]'''),
        series: parseCatalogSeriesJson(r'''[
          {"id": "hk_collab", "brandId": "pop_mart", "ipId": "the_monsters",
           "displayName": "THE MONSTERS × HELLO KITTY - Vinyl Plush",
           "releaseDate": "2024-01-01", "isBlindBox": true, "imageKey": "hk_collab"},
          {"id": "macaron", "brandId": "pop_mart", "ipId": "the_monsters",
           "displayName": "THE MONSTERS - Exciting Macaron Vinyl Face Blind Box",
           "releaseDate": "2023-10-27", "isBlindBox": true, "imageKey": "macaron"}
        ]'''),
        figures: parseCatalogFiguresJson(r'''[
          {"id": "fig_hello", "seriesId": "hk_collab", "brandId": "pop_mart",
           "ipId": "the_monsters", "displayName": "Hello Vinyl", "isSecret": false,
           "sortOrder": 1, "imageKey": "fig_hello"},
          {"id": "fig_soy", "seriesId": "macaron", "brandId": "pop_mart",
           "ipId": "the_monsters", "displayName": "Soymilk", "isSecret": false,
           "sortOrder": 1, "imageKey": "fig_soy"}
        ]'''),
      );
    });

    test('separator title matches spaced query', () {
      final svc = CatalogSearchService(bundle);
      final r = svc.search('the monsters hello kitty');
      expect(r.map((e) => e.figureId).toSet(), {'fig_hello'});
    });

    test('token order does not matter', () {
      final svc = CatalogSearchService(bundle);
      expect(svc.search('hello kitty monsters'), isNotEmpty);
    });

    test('partial token set matches', () {
      final svc = CatalogSearchService(bundle);
      expect(svc.search('monsters hello'), isNotEmpty);
      expect(svc.search('vinyl hello'), isNotEmpty);
    });

    test('unrelated token rejects match', () {
      final svc = CatalogSearchService(bundle);
      expect(svc.search('football kitty'), isEmpty);
    });

    test('phrase-only regression: single token still works', () {
      final svc = CatalogSearchService(bundle);
      expect(svc.search('soymilk'), hasLength(1));
    });
  });

  group('filterShelfSeriesBySearch token matching', () {
    test('custom series matches tokens across name and brand', () {
      final series = [
        const ShelfSeries(
          id: 's1',
          name: 'Hello Vinyl Drop',
          brand: 'POP MART',
          ipName: 'THE MONSTERS',
          figures: [],
          shelfAccent: Color(0xFFE8DEF5),
        ),
      ];
      expect(filterShelfSeriesBySearch(series, 'pop mart hello'), hasLength(1));
      expect(filterShelfSeriesBySearch(series, 'football hello'), isEmpty);
    });

    test('empty query returns same list reference', () {
      final series = [
        const ShelfSeries(
          id: 's1',
          name: 'Alpha',
          brand: 'Brand',
          ipName: 'IP',
          figures: [],
          shelfAccent: Color(0xFFE8DEF5),
        ),
      ];
      expect(identical(filterShelfSeriesBySearch(series, ''), series), isTrue);
    });
  });

  group('marketListingMatchesFreeText token matching', () {
    MarketListing makeListing({
      required String name,
      required String series,
      required String brand,
    }) {
      return MarketListing(
        id: 'm1',
        collectible: Collectible(
          id: 'c1',
          name: name,
          series: series,
          brand: brand,
          releaseDate: DateTime(2024, 1, 1),
          imageUrl: '',
        ),
        currentPriceUsd: 42,
        priceChangePercent: 0,
        listingCount: 1,
      );
    }

    test('separator and token AND across listing fields', () {
      final listing = makeListing(
        name: 'Plush',
        series: 'THE MONSTERS × HELLO KITTY',
        brand: 'POP MART',
      );
      expect(marketListingMatchesFreeText(listing, 'hello kitty monsters'), isTrue);
      expect(marketListingMatchesFreeText(listing, 'football kitty'), isFalse);
    });

    test('empty query matches all', () {
      final listing = makeListing(name: 'A', series: 'B', brand: 'C');
      expect(marketListingMatchesFreeText(listing, ''), isTrue);
      expect(marketListingMatchesFreeText(listing, '   '), isTrue);
    });
  });

  group('SearchPlaceholders', () {
    test('local catalog and market hints match for shared field coverage', () {
      expect(SearchPlaceholders.localCatalog, SearchPlaceholders.localMarket);
      expect(
        SearchPlaceholders.localCatalog,
        'Search figures, series, IPs, or brands…',
      );
    });
  });

  group('CatalogSearchHistoryRules Search V2', () {
    test('normalize lowercases and folds separators', () {
      expect(
        CatalogSearchHistoryRules.normalize('  LABUBU  '),
        'labubu',
      );
    });

    test('deduplicates case-insensitively after normalize', () {
      final result = CatalogSearchHistoryRules.add(
        ['labubu'],
        'LABUBU',
      );
      expect(result, equals(['labubu']));
    });

    test('Labubu variants collapse to one entry', () {
      var list = CatalogSearchHistoryRules.add([], 'Labubu');
      list = CatalogSearchHistoryRules.add(list, 'LABUBU');
      list = CatalogSearchHistoryRules.add(list, '  labubu  ');
      expect(list, equals(['labubu']));
    });
  });
}
