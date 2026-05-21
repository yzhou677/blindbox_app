import 'package:blindbox_app/features/catalog/catalog_seed_loader.dart';
import 'package:blindbox_app/features/catalog/search/catalog_search_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late CatalogSeedBundle bundle;

  setUp(() {
    bundle = CatalogSeedBundle(
      brands: parseCatalogBrandsJson(r'''[
        {"id": "pop_mart", "displayName": "POP MART", "aliases": ["POPMART"]}
      ]'''),
      ips: parseCatalogIpsJson(r'''[
        {"id": "the_monsters", "brandId": "pop_mart", "displayName": "THE MONSTERS",
         "aliases": ["Labubu"]},
        {"id": "hirono", "brandId": "pop_mart", "displayName": "Hirono", "aliases": []}
      ]'''),
      series: parseCatalogSeriesJson(r'''[
        {"id": "macaron", "brandId": "pop_mart", "ipId": "the_monsters",
         "displayName": "THE MONSTERS - Exciting Macaron Vinyl Face Blind Box",
         "releaseDate": "2023-10-27", "isBlindBox": true,
         "thumbnailAsset": "assets/catalog/series/macaron.png"},
        {"id": "wild", "brandId": "pop_mart", "ipId": "hirono",
         "displayName": "Hirono Boundary — Test Series", "releaseDate": "2026-04-02",
         "isBlindBox": true, "thumbnailAsset": "assets/catalog/series/wild.png"}
      ]'''),
      figures: parseCatalogFiguresJson(r'''[
        {"id": "fig_soy", "seriesId": "macaron", "brandId": "pop_mart",
         "ipId": "the_monsters", "displayName": "Soymilk", "isSecret": false,
         "sortOrder": 1, "thumbnailAsset": "assets/f/soy.png"},
        {"id": "fig_lychee", "seriesId": "macaron", "brandId": "pop_mart",
         "ipId": "the_monsters", "displayName": "Lychee Berry", "isSecret": false,
         "sortOrder": 2, "thumbnailAsset": "assets/f/lychee.png"},
        {"id": "fig_chase", "seriesId": "macaron", "brandId": "pop_mart",
         "ipId": "the_monsters", "displayName": "Chestnut Cocoa", "isSecret": true,
         "rarityLabel": "1/72", "sortOrder": 999, "thumbnailAsset": "assets/f/chase.png"},
        {"id": "fig_hirono", "seriesId": "wild", "brandId": "pop_mart", "ipId": "hirono",
         "displayName": "Quiet Rain", "isSecret": false, "sortOrder": 1,
         "thumbnailAsset": "assets/f/rain.png"}
      ]'''),
    );
  });

  test('empty query returns no results', () {
    final svc = CatalogSearchService(bundle);
    expect(svc.search(''), isEmpty);
    expect(svc.search('   '), isEmpty);
  });

  test('series keyword macaron returns macaron figures sorted by sortOrder', () {
    final svc = CatalogSearchService(bundle);
    final r = svc.search('macaron');
    expect(r, hasLength(3));
    expect(r.map((e) => e.figureId).toList(), ['fig_soy', 'fig_lychee', 'fig_chase']);
  });

  test('figure name substring chestnut ranks via figure match', () {
    final svc = CatalogSearchService(bundle);
    final r = svc.search('chestnut');
    expect(r, hasLength(1));
    expect(r.single.figureId, 'fig_chase');
    expect(r.single.isSecret, true);
  });

  test('exact figure name beats series-only match for same figure', () {
    final svc = CatalogSearchService(bundle);
    final r = svc.search('soymilk');
    expect(r.first.figureId, 'fig_soy');
    expect(r.first.figureName, 'Soymilk');
  });

  test('labubu matches via IP alias for monsters lineup', () {
    final svc = CatalogSearchService(bundle);
    final r = svc.search('labubu');
    expect(r.map((e) => e.figureId).toSet(), {'fig_soy', 'fig_lychee', 'fig_chase'});
  });

  test('hirono matches IP display and boundary matches series title', () {
    final svc = CatalogSearchService(bundle);
    final hirono = svc.search('hirono').map((e) => e.figureId).toSet();
    expect(hirono, contains('fig_hirono'));

    final boundary = svc.search('boundary');
    expect(boundary.map((e) => e.figureId), ['fig_hirono']);
  });

  test('figure substring ranks before series-only matches', () {
    final svc = CatalogSearchService(bundle);
    final r = svc.search('lychee');
    expect(r.first.figureId, 'fig_lychee');
    expect(r.first.figureName, 'Lychee Berry');
  });

  test('brand alias popmart matches at weak tier', () {
    final svc = CatalogSearchService(bundle);
    final r = svc.search('popmart');
    expect(r.length, 4);
  });

  test('no match for unrelated string', () {
    final svc = CatalogSearchService(bundle);
    expect(svc.search('zzznope'), isEmpty);
  });

  test('normalize collapses whitespace for query', () {
    expect(normalizeCatalogSearchQuery('  Macaron  '), 'macaron');
  });
}
