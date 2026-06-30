import 'package:blindbox_app/features/catalog/application/catalog_bundle_cache.dart';
import 'package:blindbox_app/features/catalog/application/catalog_bundle_provider.dart';
import 'package:blindbox_app/features/catalog/catalog_seed_loader.dart';
import 'package:blindbox_app/features/catalog/models/catalog_brand.dart';
import 'package:blindbox_app/features/catalog/models/catalog_ip.dart';
import 'package:blindbox_app/features/catalog/models/catalog_series.dart';
import 'package:blindbox_app/features/home/application/home_feed_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

CatalogSeedBundle _bundle(List<CatalogSeries> series) => CatalogSeedBundle(
      brands: const [CatalogBrand(id: 'popmart', displayName: 'POP MART')],
      ips: const [
        CatalogIp(id: 'skullpanda', brandId: 'popmart', displayName: 'Skullpanda'),
      ],
      series: series,
      figures: const [],
    );

CatalogSeries _series(String id, String date) => CatalogSeries(
      id: id,
      brandId: 'popmart',
      ipId: 'skullpanda',
      displayName: id,
      releaseDate: date,
      isBlindBox: true,
      imageKey: id,
    );

void main() {
  setUp(CatalogBundleCache.resetForTest);
  tearDown(CatalogBundleCache.resetForTest);

  test('homeFeedSnapshotProvider recomputes after catalog bundle replaced', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(catalogBundleRevisionProvider);

    final seedBundle = _bundle([
      _series('seed_only_series', '2026-05-10'),
    ]);
    CatalogBundleCache.prime(seedBundle);

    final feedBefore = await container.read(homeFeedSnapshotProvider.future);
    expect(
      feedBefore.latest.map((r) => r.dropId),
      contains('seed_only_series'),
    );

    final firestoreBundle = _bundle([
      _series('firestore_only_series', '2026-05-15'),
    ]);
    CatalogBundleCache.prime(firestoreBundle);
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
}
