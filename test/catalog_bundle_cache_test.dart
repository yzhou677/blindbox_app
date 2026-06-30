import 'dart:async';

import 'package:blindbox_app/features/catalog/application/catalog_bundle_cache.dart';
import 'package:blindbox_app/features/catalog/catalog_seed_loader.dart';
import 'package:blindbox_app/features/catalog/models/catalog_brand.dart';
import 'package:blindbox_app/features/catalog/models/catalog_ip.dart';
import 'package:blindbox_app/features/catalog/models/catalog_series.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

CatalogSeedBundle _tinyBundle({String seriesId = 's1'}) => CatalogSeedBundle(
      brands: const [CatalogBrand(id: 'b', displayName: 'B')],
      ips: const [CatalogIp(id: 'ip', brandId: 'b', displayName: 'IP')],
      series: [
        CatalogSeries(
          id: seriesId,
          brandId: 'b',
          ipId: 'ip',
          displayName: 'S',
          releaseDate: '2026-01-01',
          isBlindBox: true,
          imageKey: seriesId,
        ),
      ],
      figures: const [],
    );

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    CatalogBundleCache.resetForTest();
  });

  tearDown(CatalogBundleCache.resetForTest);

  test('prime and current return same bundle without reload', () async {
    final b = _tinyBundle();
    CatalogBundleCache.prime(b);
    expect(CatalogBundleCache.current, same(b));
    expect(CatalogBundleCache.isCatalogReady, isTrue);
    expect(await CatalogBundleCache.getOrLoad(), same(b));
  });

  group('bootstrap placeholder readiness', () {
    test('loadOfflineFirst empty bootstrap is not catalog-ready', () async {
      final gate = Completer<void>();
      CatalogBundleCache.hasCompletedFirestoreSyncOverride = () async => true;
      CatalogBundleCache.loadPersistedOverride = () async => null;
      CatalogBundleCache.loadFirestoreOverride = () async {
        await gate.future;
        return _tinyBundle();
      };

      final offline = await CatalogBundleCache.loadOfflineFirst();

      expect(offline.series, isEmpty);
      expect(CatalogBundleCache.lastStartupSource, CatalogBundleLoadSource.empty);
      expect(CatalogBundleCache.hasValue, isTrue);
      expect(CatalogBundleCache.isCatalogReady, isFalse);
      expect(CatalogBundleCache.memoryOriginForTest,
          CatalogBundleMemoryOrigin.bootstrapPlaceholder);

      gate.complete();
    });

    test('getOrLoad waits for Firestore refresh after empty bootstrap', () async {
      final remote = _tinyBundle();
      var fetchCount = 0;
      final gate = Completer<void>();

      CatalogBundleCache.hasCompletedFirestoreSyncOverride = () async => true;
      CatalogBundleCache.loadPersistedOverride = () async => null;
      CatalogBundleCache.loadFirestoreOverride = () async {
        fetchCount++;
        await gate.future;
        return remote;
      };

      final offline = await CatalogBundleCache.loadOfflineFirst();
      expect(offline.series, isEmpty);

      final getOrLoadFuture = CatalogBundleCache.getOrLoad();
      var completed = false;
      unawaited(getOrLoadFuture.then((_) => completed = true));

      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(completed, isFalse);
      expect(fetchCount, 1);

      gate.complete();
      final loaded = await getOrLoadFuture;

      expect(loaded.series.single.id, 's1');
      expect(CatalogBundleCache.isCatalogReady, isTrue);
      expect(fetchCount, 1);
    });

    test('concurrent getOrLoad share one Firestore refresh after empty bootstrap',
        () async {
      final remote = _tinyBundle(seriesId: 'remote');
      var fetchCount = 0;
      final gate = Completer<void>();

      CatalogBundleCache.hasCompletedFirestoreSyncOverride = () async => true;
      CatalogBundleCache.loadPersistedOverride = () async => null;
      CatalogBundleCache.loadFirestoreOverride = () async {
        fetchCount++;
        await gate.future;
        return remote;
      };

      await CatalogBundleCache.loadOfflineFirst();

      final first = CatalogBundleCache.getOrLoad();
      final second = CatalogBundleCache.getOrLoad();

      gate.complete();
      final results = await Future.wait([first, second]);

      expect(fetchCount, 1);
      expect(results[0].series.single.id, 'remote');
      expect(results[1].series.single.id, 'remote');
      expect(identical(results[0], results[1]), isTrue);
    });

    test('Firestore refresh replaces bundle and notifies listeners', () async {
      final remote = _tinyBundle(seriesId: 'fresh');
      CatalogBundleCache.hasCompletedFirestoreSyncOverride = () async => true;
      CatalogBundleCache.loadPersistedOverride = () async => null;
      CatalogBundleCache.loadFirestoreOverride = () async => remote;

      await CatalogBundleCache.loadOfflineFirst();

      var notified = false;
      CatalogBundleCache.onBundleReplaced = () => notified = true;

      final loaded = await CatalogBundleCache.getOrLoad();

      expect(loaded.series.single.id, 'fresh');
      expect(notified, isTrue);
      expect(CatalogBundleCache.current?.series.single.id, 'fresh');
      expect(CatalogBundleCache.memoryOriginForTest,
          CatalogBundleMemoryOrigin.firestore);
    });

    test('loadOfflineFirst refresh and getOrLoad do not duplicate Firestore fetch',
        () async {
      final remote = _tinyBundle();
      var fetchCount = 0;
      final gate = Completer<void>();

      CatalogBundleCache.hasCompletedFirestoreSyncOverride = () async => true;
      CatalogBundleCache.loadPersistedOverride = () async => null;
      CatalogBundleCache.loadFirestoreOverride = () async {
        fetchCount++;
        await gate.future;
        return remote;
      };

      await CatalogBundleCache.loadOfflineFirst();
      expect(fetchCount, 1);

      final getOrLoadFuture = CatalogBundleCache.getOrLoad();
      final refreshFuture = CatalogBundleCache.refreshFromFirestore(force: true);

      gate.complete();

      await Future.wait([getOrLoadFuture, refreshFuture]);

      expect(fetchCount, 1);
      expect(CatalogBundleCache.current?.series.single.id, 's1');
    });

    test('resolved empty after failed refresh does not re-fetch on getOrLoad',
        () async {
      var fetchCount = 0;
      CatalogBundleCache.hasCompletedFirestoreSyncOverride = () async => true;
      CatalogBundleCache.loadPersistedOverride = () async => null;
      CatalogBundleCache.loadFirestoreOverride = () async {
        fetchCount++;
        throw StateError('offline');
      };

      await CatalogBundleCache.loadOfflineFirst();
      await CatalogBundleCache.refreshFromFirestore(force: true);

      expect(fetchCount, 1);
      expect(CatalogBundleCache.isCatalogReady, isTrue);
      expect(CatalogBundleCache.memoryOriginForTest,
          CatalogBundleMemoryOrigin.resolved);
      expect(CatalogBundleCache.current?.series, isEmpty);

      final loaded = await CatalogBundleCache.getOrLoad();

      expect(fetchCount, 1);
      expect(loaded.series, isEmpty);
    });

    test('persisted path returns immediately from getOrLoad without placeholder',
        () async {
      final persisted = _tinyBundle(seriesId: 'persisted');
      CatalogBundleCache.loadPersistedOverride = () async => persisted;
      CatalogBundleCache.loadFirestoreOverride = () async {
        throw StateError('should not block getOrLoad');
      };

      await CatalogBundleCache.loadOfflineFirst();

      expect(CatalogBundleCache.isCatalogReady, isTrue);
      expect(CatalogBundleCache.memoryOriginForTest,
          CatalogBundleMemoryOrigin.persisted);

      final loaded = await CatalogBundleCache.getOrLoad();

      expect(loaded.series.single.id, 'persisted');
      expect(identical(loaded, persisted), isTrue);
    });

    test('TTL-skipped startup refresh falls through getOrLoad to network load',
        () async {
      final remote = _tinyBundle(seriesId: 'from_network');
      var fetchCount = 0;

      CatalogBundleCache.hasCompletedFirestoreSyncOverride = () async => true;
      CatalogBundleCache.loadPersistedOverride = () async => null;
      CatalogBundleCache.setLastFirestoreRefreshAtForTest(DateTime.now());
      CatalogBundleCache.loadFirestoreOverride = () async {
        fetchCount++;
        return remote;
      };

      await CatalogBundleCache.loadOfflineFirst();
      expect(CatalogBundleCache.memoryOriginForTest,
          CatalogBundleMemoryOrigin.bootstrapPlaceholder);

      final loaded = await CatalogBundleCache.getOrLoad();

      expect(fetchCount, 1);
      expect(loaded.series.single.id, 'from_network');
      expect(CatalogBundleCache.isCatalogReady, isTrue);
    });
  });
}
