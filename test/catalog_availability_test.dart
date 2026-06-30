import 'dart:async';

import 'package:blindbox_app/features/catalog/application/catalog_availability.dart';
import 'package:blindbox_app/features/catalog/application/catalog_bundle_cache.dart';
import 'package:blindbox_app/features/catalog/application/catalog_bundle_provider.dart';
import 'package:blindbox_app/features/catalog/catalog_bundle.dart';
import 'package:blindbox_app/features/catalog/models/catalog_brand.dart';
import 'package:blindbox_app/features/catalog/models/catalog_ip.dart';
import 'package:blindbox_app/features/catalog/models/catalog_series.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

CatalogSeedBundle _bundle({String seriesId = 's1'}) => CatalogSeedBundle(
      brands: const [CatalogBrand(id: 'b', displayName: 'B')],
      ips: const [CatalogIp(id: 'ip', brandId: 'b', displayName: 'IP')],
      series: [
        CatalogSeries(
          id: seriesId,
          brandId: 'b',
          ipId: 'ip',
          displayName: seriesId,
          releaseDate: '2026-05-10',
          isBlindBox: true,
          imageKey: seriesId,
        ),
      ],
      figures: const [],
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

  test('bootstrap placeholder resolves to loading', () async {
    final container = _container();
    CatalogBundleCache.loadPersistedOverride = () async => null;
    CatalogBundleCache.loadFirestoreOverride = () async {
      await Completer<void>().future;
      return _bundle();
    };

    await CatalogBundleCache.loadOfflineFirst();

    final availability = container.read(catalogAvailabilityProvider);
    expect(availability.state, CatalogAvailabilityUiState.loading);
  });

  test('resolved empty bundle resolves to offline first launch', () async {
    final container = _container();
    CatalogBundleCache.prime(const CatalogSeedBundle(
      brands: [],
      ips: [],
      series: [],
      figures: [],
    ));
    CatalogBundleCache.resetForTest();
    container.read(catalogBundleRevisionProvider);

    CatalogBundleCache.loadPersistedOverride = () async => null;
    CatalogBundleCache.loadFirestoreOverride = () async {
      throw StateError('offline');
    };

    await CatalogBundleCache.loadOfflineFirst();
    await CatalogBundleCache.refreshFromFirestore(force: true);
    await container.read(catalogBundleProvider.future);

    final availability = container.read(catalogAvailabilityProvider);
    expect(availability.state, CatalogAvailabilityUiState.offlineFirstLaunch);
    expect(availability.isCatalogUsable, isFalse);
  });

  test('catalog-ready bundle resolves to ready', () async {
    final container = _container();
    CatalogBundleCache.prime(_bundle());
    await container.read(catalogBundleProvider.future);

    final availability = container.read(catalogAvailabilityProvider);
    expect(availability.state, CatalogAvailabilityUiState.ready);
    expect(availability.isCatalogUsable, isTrue);
  });

  test('in-flight refresh keeps catalog usable as refreshing', () async {
    final container = _container();
    CatalogBundleCache.prime(_bundle());
    await container.read(catalogBundleProvider.future);

    CatalogBundleCache.loadFirestoreOverride = () async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
      return _bundle(seriesId: 'fresh');
    };
    unawaited(CatalogBundleCache.refreshFromFirestore(force: true));

    final availability = container.read(catalogAvailabilityProvider);
    expect(availability.state, CatalogAvailabilityUiState.refreshing);
    expect(availability.isCatalogUsable, isTrue);
  });
}
