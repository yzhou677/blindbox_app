import 'package:blindbox_app/features/catalog/adapters/catalog_seed_to_collection_template.dart';
import 'package:blindbox_app/features/catalog/catalog_bundle.dart';
import 'package:blindbox_app/features/catalog/data/catalog_bundle_lookup.dart';
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

  test('lookup matches adapter template output', () async {
    final lookup = CatalogBundleLookup.fromBundle(bundle);
    final fromLookup = lookup.seriesTemplate('dimoo_test_series');
    final fromAdapter = await catalogTemplateFromSeedSeries(
      bundle,
      'dimoo_test_series',
      resolveFigureImages: false,
      lookup: lookup,
    );
    expect(fromLookup?.templateId, fromAdapter?.templateId);
    expect(
      fromLookup?.figures.map((f) => f.templateFigureId).toList(),
      fromAdapter?.figures.map((f) => f.templateFigureId).toList(),
    );
  });

  test('lookup figureCountInSeries avoids full-bundle scan', () {
    final figures = <CatalogFigure>[];
    for (var i = 0; i < 5000; i++) {
      figures.add(
        CatalogFigure(
          id: 'fig_$i',
          seriesId: i == 4999 ? 'target_series' : 'other_series',
          brandId: 'pop_mart',
          ipId: 'ip',
          displayName: 'Figure $i',
          imageKey: 'fig_$i',
          isSecret: false,
          sortOrder: i,
        ),
      );
    }
    final large = CatalogSeedBundle(
      brands: bundle.brands,
      ips: bundle.ips,
      series: parseCatalogSeriesJson(r'''[
        {"id": "target_series", "brandId": "pop_mart", "ipId": "dimoo",
         "displayName": "Target", "releaseDate": "2026-01-01", "isBlindBox": true,
         "imageKey": "target", "aliases": []}
      ]'''),
      figures: figures,
    );

    final lookup = CatalogBundleLookup.fromBundle(large);
    expect(lookup.figureCountInSeries('target_series'), 1);
    expect(lookup.seriesTemplate('target_series')!.figures.single.name, 'Figure 4999');
  });

  test('seriesTemplate build stays under budget for typical lineup', () {
    final figures = <CatalogFigure>[];
    for (var i = 0; i < 24; i++) {
      figures.add(
        CatalogFigure(
          id: 'fig_$i',
          seriesId: 'big_series',
          brandId: 'pop_mart',
          ipId: 'dimoo',
          displayName: 'Figure $i',
          imageKey: 'fig_$i',
          isSecret: i.isOdd,
          sortOrder: i,
        ),
      );
    }
    final large = CatalogSeedBundle(
      brands: bundle.brands,
      ips: bundle.ips,
      series: parseCatalogSeriesJson(r'''[
        {"id": "big_series", "brandId": "pop_mart", "ipId": "dimoo",
         "displayName": "Big", "releaseDate": "2026-01-01", "isBlindBox": true,
         "imageKey": "big", "aliases": []}
      ]'''),
      figures: figures,
    );
    final lookup = CatalogBundleLookup.fromBundle(large);

    final sw = Stopwatch()..start();
    for (var i = 0; i < 200; i++) {
      lookup.seriesTemplate('big_series');
    }
    sw.stop();

    expect(sw.elapsedMicroseconds, lessThan(50000),
        reason: '200 template builds should stay well under one frame');
  });
}
