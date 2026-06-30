import 'package:blindbox_app/features/catalog/adapters/catalog_seed_to_collection_template.dart';
import 'package:blindbox_app/features/catalog/catalog_bundle.dart';
import 'package:blindbox_app/features/catalog/models/catalog_figure.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late CatalogSeedBundle bundle;

  setUp(() {
    bundle = CatalogSeedBundle(
      brands: parseCatalogBrandsJson(r'''[
        {"id": "pop_mart", "displayName": "POP MART", "aliases": []}
      ]'''),
      ips: parseCatalogIpsJson(r'''[
        {"id": "dimoo", "brandId": "pop_mart", "displayName": "DIMOO", "aliases": []}
      ]'''),
      series: parseCatalogSeriesJson(r'''[
        {"id": "dimoo_test_series", "brandId": "pop_mart", "ipId": "dimoo",
         "displayName": "DIMOO Test", "releaseDate": "2026-01-01", "isBlindBox": true,
         "imageKey": "dimoo_test_series", "aliases": []}
      ]'''),
      figures: parseCatalogFiguresJson(r'''[
        {"id": "dimoo_fig_reg", "seriesId": "dimoo_test_series", "brandId": "pop_mart",
         "ipId": "dimoo", "displayName": "Regular", "isSecret": false, "sortOrder": 1,
         "imageKey": "dimoo_fig_reg"},
        {"id": "dimoo_fig_secret", "seriesId": "dimoo_test_series", "brandId": "pop_mart",
         "ipId": "dimoo", "displayName": "Secret", "isSecret": true, "rarityLabel": "1:288",
         "sortOrder": 2, "imageKey": "dimoo_fig_secret"}
      ]'''),
    );
  });

  test('returns null for unknown series', () async {
    final t = await catalogTemplateFromSeedSeries(bundle, 'missing', resolveFigureImages: false);
    expect(t, isNull);
  });

  test('builds template with sorted figures and taxonomy ids', () async {
    final t = await catalogTemplateFromSeedSeries(
      bundle,
      'dimoo_test_series',
      resolveFigureImages: false,
    );
    expect(t, isNotNull);
    expect(t!.templateId, 'dimoo_test_series');
    expect(t.brand, 'POP MART');
    expect(t.ipName, 'DIMOO');
    expect(t.figures.map((f) => f.templateFigureId), ['dimoo_fig_reg', 'dimoo_fig_secret']);
    expect(t.figures.last.catalogImageKey, 'dimoo_fig_secret');
    expect(t.figures.last.rarity, '1:288');
    expect(t.figures.first.rarity, 'Regular');
  });

  test('secret without rarityLabel uses Secret fallback', () async {
    final solo = CatalogSeedBundle(
      brands: bundle.brands,
      ips: bundle.ips,
      series: bundle.series,
      figures: [
        CatalogFigure(
          id: 'solo_secret',
          seriesId: 'dimoo_test_series',
          brandId: 'pop_mart',
          ipId: 'dimoo',
          displayName: 'Lonely Secret',
          imageKey: 'solo_secret',
          isSecret: true,
          sortOrder: 1,
        ),
      ],
    );
    final t = await catalogTemplateFromSeedSeries(
      solo,
      'dimoo_test_series',
      resolveFigureImages: false,
    );
    expect(t!.figures.single.rarity, 'Secret');
  });
}
