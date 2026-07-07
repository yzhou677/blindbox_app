import 'package:blindbox_app/core/search/search_matcher.dart';
import 'package:blindbox_app/core/search/search_normalizer.dart';
import 'package:blindbox_app/core/search/search_placeholders.dart';
import 'package:blindbox_app/core/search/search_tokenizer.dart';
import 'package:blindbox_app/features/catalog/catalog_bundle.dart';
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
        SearchNormalizer.normalize('THE MONSTERS ? HELLO KITTY'),
        'the monsters hello kitty',
      );
      expect(
        SearchNormalizer.normalize('Hirono Boundary — Test'),
        'hirono boundary test',
      );
      expect(SearchNormalizer.normalize('pop_mart/sku'), 'pop mart sku');
    });

    test('strips decorative symbols and parentheses', () {
      expect(SearchNormalizer.normalize('ZERO°'), 'zero');
      expect(SearchNormalizer.normalize('POP MART®'), 'pop mart');
      expect(SearchNormalizer.normalize('Haikyu!!'), 'haikyu');
      expect(
        SearchNormalizer.normalize('SKULLPANDA (Limited)'),
        'skullpanda limited',
      );
    });

    test('strips product-title boilerplate phrases', () {
      expect(
        SearchNormalizer.normalize(
          'THE MONSTERS - Exciting Macaron Vinyl Face Blind Box',
        ),
        'the monsters exciting macaron',
      );
      expect(
        SearchNormalizer.normalize('SKULLPANDA Petals in Four Acts Series Figures'),
        'skullpanda petals in four acts',
      );
    });

    test('compact removes spaces from normalized text', () {
      expect(SearchNormalizer.compact('pop mart'), 'popmart');
      expect(SearchNormalizer.compact('sonny angel'), 'sonnyangel');
      expect(SearchNormalizer.compact('the monsters'), 'themonsters');
    });

    test('normalizeForMatch appends compact twin for spaced text', () {
      expect(
        SearchNormalizer.normalizeForMatch('POP MART'),
        'pop mart popmart',
      );
      expect(
        SearchNormalizer.normalizeForMatch('Sonny Angel'),
        'sonny angel sonnyangel',
      );
      expect(
        SearchNormalizer.normalizeForMatch('Skull Panda'),
        'skull panda skullpanda',
      );
      expect(
        SearchNormalizer.normalizeForMatch('THE MONSTERS'),
        'the monsters themonsters',
      );
      expect(SearchNormalizer.normalizeForMatch('macaron'), 'macaron');
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
          {"id": "pop_mart", "displayName": "POP MART", "aliases": []},
          {"id": "dreams_inc", "displayName": "Dreams Inc.", "aliases": []}
        ]'''),
        ips: parseCatalogIpsJson(r'''[
          {"id": "the_monsters", "brandId": "pop_mart", "displayName": "THE MONSTERS",
           "aliases": ["Labubu"]},
          {"id": "hello_kitty", "brandId": "pop_mart", "displayName": "HELLO KITTY", "aliases": []},
          {"id": "skullpanda", "brandId": "pop_mart", "displayName": "SKULLPANDA", "aliases": []},
          {"id": "sonny_angel", "brandId": "dreams_inc", "displayName": "Sonny Angel", "aliases": []}
        ]'''),
        series: parseCatalogSeriesJson(r'''[
          {"id": "hk_collab", "brandId": "pop_mart", "ipId": "the_monsters",
           "displayName": "THE MONSTERS ? HELLO KITTY - Vinyl Plush",
           "releaseDate": "2024-01-01", "isBlindBox": true, "imageKey": "hk_collab"},
          {"id": "macaron", "brandId": "pop_mart", "ipId": "the_monsters",
           "displayName": "THE MONSTERS - Exciting Macaron Vinyl Face Blind Box",
           "releaseDate": "2023-10-27", "isBlindBox": true, "imageKey": "macaron"},
          {"id": "sonny_animal", "brandId": "dreams_inc", "ipId": "sonny_angel",
           "displayName": "Sonny Angel Animal Series Figures",
           "releaseDate": "2024-01-01", "isBlindBox": true, "imageKey": "sonny_animal"},
          {"id": "skullpanda_sound", "brandId": "pop_mart", "ipId": "skullpanda",
           "displayName": "SKULLPANDA The Sound Series Figures",
           "releaseDate": "2024-01-01", "isBlindBox": true, "imageKey": "skullpanda_sound"}
        ]'''),
        figures: parseCatalogFiguresJson(r'''[
          {"id": "fig_hello", "seriesId": "hk_collab", "brandId": "pop_mart",
           "ipId": "the_monsters", "displayName": "Hello Vinyl", "isSecret": false,
           "sortOrder": 1, "imageKey": "fig_hello"},
          {"id": "fig_soy", "seriesId": "macaron", "brandId": "pop_mart",
           "ipId": "the_monsters", "displayName": "Soymilk", "isSecret": false,
           "sortOrder": 1, "imageKey": "fig_soy"},
          {"id": "fig_sonny", "seriesId": "sonny_animal", "brandId": "dreams_inc",
           "ipId": "sonny_angel", "displayName": "Rabbit", "isSecret": false,
           "sortOrder": 1, "imageKey": "fig_sonny"},
          {"id": "fig_skull", "seriesId": "skullpanda_sound", "brandId": "pop_mart",
           "ipId": "skullpanda", "displayName": "Choir", "isSecret": false,
           "sortOrder": 1, "imageKey": "fig_skull"}
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

    test('compact brand query matches without catalog alias', () {
      final svc = CatalogSearchService(bundle);
      expect(svc.search('popmart'), isNotEmpty);
      expect(svc.search('pop mart'), isNotEmpty);
    });

    test('compact IP query matches without catalog alias', () {
      final svc = CatalogSearchService(bundle);
      expect(svc.search('themonsters'), isNotEmpty);
      expect(svc.search('skullpanda'), isNotEmpty);
      expect(svc.search('sonnyangel'), isNotEmpty);
    });

    test('compact spaced IP query matches without catalog alias', () {
      final svc = CatalogSearchService(bundle);
      expect(svc.search('sonny angel'), isNotEmpty);
    });

    test('boilerplate-stripped series title matches content tokens', () {
      final svc = CatalogSearchService(bundle);
      expect(svc.search('exciting macaron'), isNotEmpty);
    });

    test('labubu identity alias still matches when present', () {
      final svc = CatalogSearchService(bundle);
      expect(svc.search('labubu'), isNotEmpty);
    });
  });

  group('Search normalization smoke tests', () {
    late CatalogSeedBundle bundle;
    late CatalogSearchService svc;

    setUp(() {
      bundle = CatalogSeedBundle(
        brands: parseCatalogBrandsJson(r'''[
          {"id": "pop_mart", "displayName": "POP MART", "aliases": []},
          {"id": "dreams_inc", "displayName": "Dreams Inc.", "aliases": []}
        ]'''),
        ips: parseCatalogIpsJson(r'''[
          {"id": "the_monsters", "brandId": "pop_mart", "displayName": "THE MONSTERS",
           "aliases": ["Labubu"]},
          {"id": "skullpanda", "brandId": "pop_mart", "displayName": "SKULLPANDA", "aliases": []},
          {"id": "sonny_angel", "brandId": "dreams_inc", "displayName": "Sonny Angel", "aliases": []}
        ]'''),
        series: parseCatalogSeriesJson(r'''[
          {"id": "macaron", "brandId": "pop_mart", "ipId": "the_monsters",
           "displayName": "THE MONSTERS - Exciting Macaron Vinyl Face Blind Box",
           "releaseDate": "2023-10-27", "isBlindBox": true, "imageKey": "macaron"},
          {"id": "sonny_animal", "brandId": "dreams_inc", "ipId": "sonny_angel",
           "displayName": "Sonny Angel Animal Series Figures",
           "releaseDate": "2024-01-01", "isBlindBox": true, "imageKey": "sonny_animal"},
          {"id": "skullpanda_sound", "brandId": "pop_mart", "ipId": "skullpanda",
           "displayName": "SKULLPANDA The Sound Series Figures",
           "releaseDate": "2024-01-01", "isBlindBox": true, "imageKey": "skullpanda_sound"}
        ]'''),
        figures: parseCatalogFiguresJson(r'''[
          {"id": "fig_soy", "seriesId": "macaron", "brandId": "pop_mart",
           "ipId": "the_monsters", "displayName": "Soymilk", "isSecret": false,
           "sortOrder": 1, "imageKey": "fig_soy"},
          {"id": "fig_sonny", "seriesId": "sonny_animal", "brandId": "dreams_inc",
           "ipId": "sonny_angel", "displayName": "Rabbit", "isSecret": false,
           "sortOrder": 1, "imageKey": "fig_sonny"},
          {"id": "fig_skull", "seriesId": "skullpanda_sound", "brandId": "pop_mart",
           "ipId": "skullpanda", "displayName": "Choir", "isSecret": false,
           "sortOrder": 1, "imageKey": "fig_skull"}
        ]'''),
      );
      svc = CatalogSearchService(bundle);
    });

    Set<String> figureIds(String query) =>
        svc.search(query).map((r) => r.figureId).toSet();

    test('popmart and POP MART return the same figures', () {
      final compact = figureIds('popmart');
      final spaced = figureIds('POP MART');
      expect(compact, isNotEmpty);
      expect(spaced, compact);
      expect(compact, containsAll(['fig_soy', 'fig_skull']));
    });

    test('sonnyangel and Sonny Angel return the same figures', () {
      final compact = figureIds('sonnyangel');
      final spaced = figureIds('Sonny Angel');
      expect(compact, equals({'fig_sonny'}));
      expect(spaced, compact);
    });

    test('skullpanda matches SKULLPANDA IP figures', () {
      expect(figureIds('skullpanda'), equals({'fig_skull'}));
      expect(figureIds('SKULLPANDA'), figureIds('skullpanda'));
    });

    test('themonsters matches THE MONSTERS IP figures', () {
      final compact = figureIds('themonsters');
      final spaced = figureIds('THE MONSTERS');
      expect(compact, equals({'fig_soy'}));
      expect(spaced, compact);
    });

    test('blind box alone is boilerplate-only and yields no catalog results', () {
      expect(SearchNormalizer.normalize('blind box'), isEmpty);
      expect(SearchTokenizer.tokenize('blind box'), isEmpty);
      expect(svc.search('blind box'), isEmpty);
    });

    test('blind box plus content tokens still matches after boilerplate strip', () {
      expect(figureIds('blind box exciting macaron'), equals({'fig_soy'}));
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
      expect(filterShelfSeriesBySearch(series, 'popmart hello'), hasLength(1));
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
        series: 'THE MONSTERS ? HELLO KITTY',
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
    test('each surface has a distinct scope-first hint', () {
      expect(
        SearchPlaceholders.collection,
        'Search your collection…',
      );
      expect(
        SearchPlaceholders.discoverCatalog,
        'Search the catalog…',
      );
      expect(
        SearchPlaceholders.market,
        'Search market listings…',
      );
      expect(SearchPlaceholders.collection, isNot(SearchPlaceholders.market));
      expect(
        SearchPlaceholders.discoverCatalog,
        isNot(SearchPlaceholders.collection),
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
