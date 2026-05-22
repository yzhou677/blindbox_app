import 'package:blindbox_app/features/catalog/catalog_seed_loader.dart';
import 'package:blindbox_app/features/catalog/models/catalog_brand.dart';
import 'package:blindbox_app/features/catalog/models/catalog_figure.dart';
import 'package:blindbox_app/features/catalog/models/catalog_ip.dart';
import 'package:blindbox_app/features/catalog/models/catalog_series.dart';
import 'package:blindbox_app/features/home/data/catalog_series_release_builder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('build carries series and figure imageKeys for UI resolve', () async {
    final bundle = CatalogSeedBundle(
      brands: const [CatalogBrand(id: 'popmart', displayName: 'POP MART')],
      ips: const [
        CatalogIp(id: 'dimoo', brandId: 'popmart', displayName: 'Dimoo'),
      ],
      series: const [
        CatalogSeries(
          id: 'series_a',
          brandId: 'popmart',
          ipId: 'dimoo',
          displayName: 'Series A',
          releaseDate: '2026-04-01',
          isBlindBox: true,
          imageKey: 'series_cover_key',
        ),
      ],
      figures: const [
        CatalogFigure(
          id: 'fig_1',
          seriesId: 'series_a',
          brandId: 'popmart',
          ipId: 'dimoo',
          displayName: 'Figure 1',
          isSecret: false,
          sortOrder: 0,
          imageKey: 'fig_key_1',
        ),
      ],
    );

    final releases = await buildSeriesReleasesFromCatalog(bundle, bundle.series);

    expect(releases, hasLength(1));
    expect(releases.first.seriesImageKey, 'series_cover_key');
    expect(releases.first.lineup.single.imageKey, 'fig_key_1');
  });
}
