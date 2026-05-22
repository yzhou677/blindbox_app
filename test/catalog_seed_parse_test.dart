import 'package:blindbox_app/features/catalog/catalog_seed_loader.dart';
import 'package:blindbox_app/features/catalog/models/catalog_brand.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('catalog seed parse', () {
    test('brand, ip, series, figure round-trip shape from seed-like JSON', () {
      const brandsJson = r'''[
        {"id": "pop_mart", "displayName": "POP MART", "aliases": ["POPMART"]}
      ]''';
      final brands = parseCatalogBrandsJson(brandsJson);
      expect(brands, hasLength(1));
      expect(brands.single, isA<CatalogBrand>());
      expect(brands.single.id, 'pop_mart');
      expect(brands.single.displayName, 'POP MART');
      expect(brands.single.aliases, ['POPMART']);

      const ipsJson = r'''[
        {"id": "hirono", "brandId": "pop_mart", "displayName": "Hirono"}
      ]''';
      final ips = parseCatalogIpsJson(ipsJson);
      expect(ips.single.aliases, isEmpty);

      const seriesJson = r'''[
        {
          "id": "s1",
          "brandId": "pop_mart",
          "ipId": "hirono",
          "displayName": "Series A",
          "releaseDate": "2026-04-02",
          "isBlindBox": true,
          "imageKey": "s1",
          "aliases": ["Series A Short"],
          "thumbnailAsset": "assets/catalog/series/legacy-can-be-ignored.png"
        }
      ]''';
      final series = parseCatalogSeriesJson(seriesJson);
      expect(series.single.releaseDate, '2026-04-02');
      expect(series.single.isBlindBox, true);
      expect(series.single.imageKey, 's1');
      expect(series.single.aliases, ['Series A Short']);

      const figuresJson = r'''[
        {
          "id": "f1",
          "seriesId": "s1",
          "brandId": "pop_mart",
          "ipId": "hirono",
          "displayName": "Fig",
          "isSecret": false,
          "sortOrder": 2,
          "thumbnailAsset": "assets/catalog/figures/f1.png"
        },
        {
          "id": "f2",
          "seriesId": "s1",
          "brandId": "pop_mart",
          "ipId": "hirono",
          "displayName": "Chase",
          "isSecret": true,
          "rarityLabel": "1/72",
          "sortOrder": 999,
          "thumbnailAsset": "assets/catalog/figures/f2.png"
        }
      ]''';
      final figures = parseCatalogFiguresJson(figuresJson);
      expect(figures.first.rarityLabel, isNull);
      expect(figures.last.rarityLabel, '1/72');
      expect(figures.last.sortOrder, 999);
      expect(figures.first.imageKey, 'f1');
      expect(figures.last.imageKey, 'f2');
    });

    test('non-array JSON yields empty lists', () {
      expect(parseCatalogBrandsJson('{}'), isEmpty);
    });
  });
}
