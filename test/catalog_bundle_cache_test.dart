import 'package:blindbox_app/features/catalog/application/catalog_bundle_cache.dart';
import 'package:blindbox_app/features/catalog/catalog_seed_loader.dart';
import 'package:blindbox_app/features/catalog/models/catalog_brand.dart';
import 'package:blindbox_app/features/catalog/models/catalog_ip.dart';
import 'package:blindbox_app/features/catalog/models/catalog_series.dart';
import 'package:flutter_test/flutter_test.dart';

CatalogSeedBundle _tinyBundle() => CatalogSeedBundle(
      brands: const [CatalogBrand(id: 'b', displayName: 'B')],
      ips: const [CatalogIp(id: 'ip', brandId: 'b', displayName: 'IP')],
      series: const [
        CatalogSeries(
          id: 's1',
          brandId: 'b',
          ipId: 'ip',
          displayName: 'S',
          releaseDate: '2026-01-01',
          isBlindBox: true,
          imageKey: 's1',
        ),
      ],
      figures: const [],
    );

void main() {
  test('prime and current return same bundle without reload', () async {
    final b = _tinyBundle();
    CatalogBundleCache.prime(b);
    expect(CatalogBundleCache.current, same(b));
    expect(await CatalogBundleCache.getOrLoad(), same(b));
  });
}
