import 'package:blindbox_app/features/catalog/application/catalog_bundle_cache.dart';
import 'package:blindbox_app/features/catalog/application/catalog_bundle_provider.dart';
import 'package:blindbox_app/features/catalog/catalog_bundle.dart';
import 'package:blindbox_app/features/catalog/models/catalog_brand.dart';
import 'package:blindbox_app/features/catalog/models/catalog_figure.dart';
import 'package:blindbox_app/features/catalog/models/catalog_ip.dart';
import 'package:blindbox_app/features/catalog/models/catalog_series.dart';
import 'package:blindbox_app/features/catalog/presentation/catalog_series_search_rows.dart';
import 'package:blindbox_app/features/home/application/home_feed_provider.dart';
import 'package:blindbox_app/features/market/data/market_catalog_identity_cache.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

CatalogSeedBundle _bundle({
  required String seriesId,
  required String figureName,
  String releaseDate = '2026-05-10',
}) =>
    CatalogSeedBundle(
      brands: const [CatalogBrand(id: 'b', displayName: 'B')],
      ips: const [CatalogIp(id: 'ip', brandId: 'b', displayName: 'IP')],
      series: [
        CatalogSeries(
          id: seriesId,
          brandId: 'b',
          ipId: 'ip',
          displayName: seriesId,
          releaseDate: releaseDate,
          isBlindBox: true,
          imageKey: seriesId,
        ),
      ],
      figures: [
        CatalogFigure(
          id: '${seriesId}_fig',
          seriesId: seriesId,
          brandId: 'b',
          ipId: 'ip',
          displayName: figureName,
          isSecret: false,
          sortOrder: 0,
          imageKey: '${seriesId}_fig',
        ),
      ],
    );

void main() {
  setUp(CatalogBundleCache.resetForTest);
  tearDown(CatalogBundleCache.resetForTest);

  ProviderContainer _container() {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(catalogBundleRevisionProvider);
    return container;
  }

  test('catalogBundleProvider returns updated bundle after replacement', () async {
    final container = _container();

    CatalogBundleCache.prime(_bundle(seriesId: 'seed', figureName: 'Seed Figure'));
    final first = await container.read(catalogBundleProvider.future);
    expect(first.series.single.id, 'seed');

    CatalogBundleCache.prime(
      _bundle(seriesId: 'remote', figureName: 'Remote Figure'),
    );
    CatalogBundleCache.triggerBundleReplacedForTest();

    final second = await container.read(catalogBundleProvider.future);
    expect(second.series.single.id, 'remote');
    expect(identical(first, second), isFalse);
  });

  test('catalogSearchServiceProvider reflects replacement bundle', () async {
    final container = _container();

    CatalogBundleCache.prime(_bundle(seriesId: 'seed', figureName: 'Seed Figure'));
    await container.read(catalogBundleProvider.future);
    final before = container.read(catalogSearchServiceProvider)!;
    expect(before.search('Seed').length, 1);
    expect(before.search('Seed').single.figureName, 'Seed Figure');

    CatalogBundleCache.prime(
      _bundle(seriesId: 'remote', figureName: 'Remote Figure'),
    );
    CatalogBundleCache.triggerBundleReplacedForTest();
    await container.read(catalogBundleProvider.future);

    final after = container.read(catalogSearchServiceProvider)!;
    expect(identical(before, after), isFalse);
    expect(after.search('Remote').length, 1);
    expect(after.search('Seed'), isEmpty);
  });

  test('buildCatalogSeriesSearchRows uses replaced bundle via provider', () async {
    final container = _container();

    CatalogBundleCache.prime(_bundle(seriesId: 'seed', figureName: 'Seed Figure'));
    final seedBundle = await container.read(catalogBundleProvider.future);
    expect(
      buildCatalogSeriesSearchRows(bundle: seedBundle, query: 'Seed').length,
      1,
    );

    CatalogBundleCache.prime(
      _bundle(seriesId: 'remote', figureName: 'Remote Figure'),
    );
    CatalogBundleCache.triggerBundleReplacedForTest();
    final remoteBundle = await container.read(catalogBundleProvider.future);

    expect(
      buildCatalogSeriesSearchRows(bundle: remoteBundle, query: 'Remote').length,
      1,
    );
    expect(
      buildCatalogSeriesSearchRows(bundle: remoteBundle, query: 'Seed'),
      isEmpty,
    );
  });

  test('MarketCatalogIdentityCache reinstalls on bundle replacement', () async {
    final container = _container();

    CatalogBundleCache.prime(_bundle(seriesId: 'seed', figureName: 'Seed Figure'));
    await container.read(catalogBundleProvider.future);
    expect(
      MarketCatalogIdentityCache.current?.seriesById('seed')?.displayName,
      'seed',
    );

    CatalogBundleCache.prime(
      _bundle(seriesId: 'remote', figureName: 'Remote Figure'),
    );
    CatalogBundleCache.triggerBundleReplacedForTest();
    await container.read(catalogBundleProvider.future);

    expect(MarketCatalogIdentityCache.current?.seriesById('seed'), isNull);
    expect(
      MarketCatalogIdentityCache.current?.seriesById('remote')?.displayName,
      'remote',
    );
  });

  test('homeFeedSnapshotProvider recomputes via catalogBundleProvider', () async {
    final container = _container();

    CatalogBundleCache.prime(
      _bundle(seriesId: 'seed_only_series', figureName: 'Seed Figure'),
    );
    final feedBefore = await container.read(homeFeedSnapshotProvider.future);
    expect(
      feedBefore.latest.map((r) => r.dropId),
      contains('seed_only_series'),
    );

    CatalogBundleCache.prime(
      _bundle(
        seriesId: 'firestore_only_series',
        figureName: 'Remote Figure',
        releaseDate: '2026-05-15',
      ),
    );
    CatalogBundleCache.triggerBundleReplacedForTest();

    final feedAfter = await container.read(homeFeedSnapshotProvider.future);
    expect(
      feedAfter.latest.map((r) => r.dropId),
      contains('firestore_only_series'),
    );
    expect(
      feedAfter.latest.map((r) => r.dropId),
      isNot(contains('seed_only_series')),
    );
  });

  test('multiple bundle replacements bump revision and refresh search', () async {
    final container = _container();
    CatalogBundleCache.prime(_bundle(seriesId: 'v1', figureName: 'V1 Figure'));
    await container.read(catalogBundleProvider.future);
    expect(container.read(catalogBundleRevisionProvider), 0);

    for (final id in ['v2', 'v3']) {
      CatalogBundleCache.prime(
        _bundle(seriesId: id, figureName: '$id Figure'),
      );
      CatalogBundleCache.triggerBundleReplacedForTest();
      await container.read(catalogBundleProvider.future);
    }

    expect(container.read(catalogBundleRevisionProvider), 2);
    final svc = container.read(catalogSearchServiceProvider)!;
    expect(svc.search('V3').length, 1);
    expect(svc.search('V1'), isEmpty);
  });

  test('revision listener disposes without leaking', () async {
    final container = ProviderContainer();
    expect(CatalogBundleCache.bundleReplacedListenerCountForTest, 0);

    container.read(catalogBundleRevisionProvider);
    expect(CatalogBundleCache.bundleReplacedListenerCountForTest, 1);

    container.dispose();
    expect(CatalogBundleCache.bundleReplacedListenerCountForTest, 0);
  });

  test('duplicate revision notifier instances share one cache listener per container',
      () async {
    final container = _container();
    expect(CatalogBundleCache.bundleReplacedListenerCountForTest, 1);

    container.read(catalogBundleRevisionProvider);
    container.read(catalogBundleRevisionProvider);
    expect(CatalogBundleCache.bundleReplacedListenerCountForTest, 1);
  });
}
