import 'package:blindbox_app/features/catalog/application/catalog_bundle_cache.dart';
import 'package:blindbox_app/features/catalog/catalog_bundle.dart';
import 'package:blindbox_app/features/catalog/models/catalog_brand.dart';
import 'package:blindbox_app/features/catalog/models/catalog_figure.dart';
import 'package:blindbox_app/features/catalog/models/catalog_ip.dart';
import 'package:blindbox_app/features/catalog/models/catalog_series.dart';
import 'package:blindbox_app/features/collection/application/add_series_catalog_providers.dart';
import 'package:blindbox_app/features/collection/application/catalog_series_shelf_commit.dart';
import 'package:blindbox_app/features/collection/application/collection_notifier.dart';
import 'package:blindbox_app/features/catalog/models/catalog_series.dart' as catalog;
import 'package:blindbox_app/features/collection/domain/collection_domain.dart'
    show CollectionSnapshot;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

CatalogSeedBundle _browseBundle() {
  return CatalogSeedBundle(
    brands: const [
      CatalogBrand(id: 'popmart', displayName: 'POP MART'),
    ],
    ips: const [
      CatalogIp(id: 'dimoo', brandId: 'popmart', displayName: 'DIMOO'),
    ],
    series: [
      for (var i = 0; i < 8; i++)
        catalog.CatalogSeries(
          id: 'series_$i',
          brandId: 'popmart',
          ipId: 'dimoo',
          displayName: 'Series $i',
          releaseDate: '2026-01-${(i + 1).toString().padLeft(2, '0')}',
          isBlindBox: true,
          imageKey: 'series_$i',
        ),
    ],
    figures: [
      for (var i = 0; i < 8; i++)
        CatalogFigure(
          id: 'series_${i}_fig',
          seriesId: 'series_$i',
          brandId: 'popmart',
          ipId: 'dimoo',
          displayName: 'Figure $i',
          isSecret: false,
          sortOrder: 0,
          imageKey: 'series_${i}_fig',
        ),
    ],
  );
}

void main() {
  setUp(() {
    CatalogBundleCache.prime(_browseBundle());
  });

  test('returns empty list when catalog bundle is unavailable', () {
    CatalogBundleCache.resetForTest();
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(addSeriesCatalogRecommendationsProvider), isEmpty);
  });

  test('keeps recommendation order stable when shelf changes', () {
    final container = ProviderContainer(
      overrides: [
        collectionNotifierProvider.overrideWith(CollectionNotifier.new),
      ],
    );
    addTearDown(container.dispose);

    final before = container.read(addSeriesCatalogRecommendationsProvider);
    expect(before, isNotEmpty);

    final template = before.first;
    commitCatalogSeriesToShelf(
      container.read(collectionNotifierProvider.notifier),
      template,
    );

    final after = container.read(addSeriesCatalogRecommendationsProvider);
    expect(
      after.map((series) => series.templateId),
      before.map((series) => series.templateId),
    );
  });
}
