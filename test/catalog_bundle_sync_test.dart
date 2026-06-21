import 'dart:io';

import 'package:blindbox_app/features/catalog/application/catalog_bundle_cache.dart';
import 'package:blindbox_app/features/catalog/catalog_seed_loader.dart';
import 'package:blindbox_app/features/catalog/data/catalog_bundle_codec.dart';
import 'package:blindbox_app/features/catalog/data/catalog_bundle_persistence.dart';
import 'package:blindbox_app/features/catalog/models/catalog_brand.dart';
import 'package:blindbox_app/features/catalog/models/catalog_figure.dart';
import 'package:blindbox_app/features/catalog/models/catalog_ip.dart';
import 'package:blindbox_app/features/catalog/models/catalog_series.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

CatalogSeedBundle _bundle({
  List<CatalogSeries>? series,
  List<CatalogFigure>? figures,
}) =>
    CatalogSeedBundle(
      brands: const [CatalogBrand(id: 'b', displayName: 'B')],
      ips: const [CatalogIp(id: 'ip', brandId: 'b', displayName: 'IP')],
      series: series ??
          const [
            CatalogSeries(
              id: 'seed_series',
              brandId: 'b',
              ipId: 'ip',
              displayName: 'Seed Series',
              releaseDate: '2026-01-01',
              isBlindBox: true,
              imageKey: 'seed_series',
            ),
          ],
      figures: figures ??
          const [
            CatalogFigure(
              id: 'seed_figure',
              seriesId: 'seed_series',
              brandId: 'b',
              ipId: 'ip',
              displayName: 'Seed Figure',
              isSecret: false,
              sortOrder: 1,
              imageKey: 'seed_figure',
            ),
          ],
    );

CatalogSeedBundle _remoteWithoutDeletedSeries() => _bundle(
      series: const [
        CatalogSeries(
          id: 'remote_series',
          brandId: 'b',
          ipId: 'ip',
          displayName: 'Remote Series',
          releaseDate: '2026-02-01',
          isBlindBox: true,
          imageKey: 'remote_series',
        ),
      ],
      figures: const [],
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempRoot;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    tempRoot = await Directory.systemTemp.createTemp('catalog_bundle_sync_test_');
    CatalogBundleCache.resetForTest();
    CatalogBundlePersistence.testRootOverride = tempRoot;
    CatalogBundleCache.loadFirestoreOverride = () async {
      throw StateError('firestore disabled in test');
    };
  });

  tearDown(() async {
    CatalogBundleCache.resetForTest();
    if (await tempRoot.exists()) {
      await tempRoot.delete(recursive: true);
    }
  });

  group('CatalogBundleCodec', () {
    test('round-trips bundle payloads', () {
      final original = _bundle();
      final decoded = CatalogBundleCodec.tryDecode(CatalogBundleCodec.encode(original));
      expect(decoded, isNotNull);
      expect(decoded!.series.single.id, 'seed_series');
      expect(decoded.figures.single.id, 'seed_figure');
    });

    test('returns null for corrupt payloads', () {
      expect(CatalogBundleCodec.tryDecode('{not json'), isNull);
      expect(CatalogBundleCodec.tryDecode('{"schemaVersion":99}'), isNull);
    });
  });

  group('CatalogBundleCache sync', () {
    test('first install uses bundled seed when no persisted snapshot exists',
        () async {
      final seed = _bundle();
      CatalogBundleCache.loadSeedOverride = () async => seed;

      final loaded = await CatalogBundleCache.loadOfflineFirst();

      expect(loaded.series.single.id, 'seed_series');
      expect(CatalogBundleCache.lastStartupSource, CatalogBundleLoadSource.seed);
      expect(await CatalogBundlePersistence.hasCompletedFirestoreSync(), isFalse);
      expect(await CatalogBundlePersistence.load(), isNull);
    });

    test('successful refresh persists bundle and marks Firestore sync complete',
        () async {
      final seed = _bundle();
      final remote = _remoteWithoutDeletedSeries();
      CatalogBundleCache.loadSeedOverride = () async => seed;
      CatalogBundleCache.loadFirestoreOverride = () async => remote;

      await CatalogBundleCache.loadOfflineFirst();
      await CatalogBundleCache.refreshFromFirestore();

      expect(await CatalogBundlePersistence.hasCompletedFirestoreSync(), isTrue);
      final persisted = await CatalogBundlePersistence.load();
      expect(persisted?.series.single.id, 'remote_series');
      expect(persisted?.series.map((s) => s.id), isNot(contains('seed_series')));
    });

    test('deleted series stays removed after cold start once sync completed',
        () async {
      final seed = _bundle(
        series: const [
          CatalogSeries(
            id: 'smiski_series_1',
            brandId: 'b',
            ipId: 'ip',
            displayName: 'Smiski',
            releaseDate: '2026-01-01',
            isBlindBox: true,
            imageKey: 'smiski_series_1',
          ),
        ],
      );
      final remote = _remoteWithoutDeletedSeries();

      CatalogBundleCache.loadSeedOverride = () async => seed;
      CatalogBundleCache.loadFirestoreOverride = () async => remote;

      await CatalogBundleCache.loadOfflineFirst();
      await CatalogBundleCache.refreshFromFirestore();

      CatalogBundleCache.resetForTest();
      CatalogBundlePersistence.testRootOverride = tempRoot;
      CatalogBundleCache.loadSeedOverride = () async => seed;
      CatalogBundleCache.loadFirestoreOverride = () async {
        throw StateError('offline');
      };

      final relaunched = await CatalogBundleCache.loadOfflineFirst();

      expect(relaunched.series.map((s) => s.id), ['remote_series']);
      expect(relaunched.series.map((s) => s.id), isNot(contains('smiski_series_1')));
      expect(
        CatalogBundleCache.lastStartupSource,
        CatalogBundleLoadSource.persisted,
      );
    });

    test('offline restart after sync serves persisted bundle without seed fallback',
        () async {
      final seed = _bundle();
      final remote = _remoteWithoutDeletedSeries();

      await CatalogBundlePersistence.save(remote);
      CatalogBundleCache.resetForTest();
      CatalogBundlePersistence.testRootOverride = tempRoot;

      CatalogBundleCache.loadSeedOverride = () async => seed;
      CatalogBundleCache.loadFirestoreOverride = () async {
        throw StateError('offline');
      };

      final loaded = await CatalogBundleCache.loadOfflineFirst();

      expect(loaded.series.single.id, 'remote_series');
      expect(loaded.series.map((s) => s.id), isNot(contains('seed_series')));
    });

    test('corrupted persisted cache falls back to seed before first sync',
        () async {
      final seed = _bundle();
      await CatalogBundlePersistence.writeCorruptBundleForTest('not-json');

      CatalogBundleCache.loadSeedOverride = () async => seed;
      CatalogBundleCache.loadFirestoreOverride = () async {
        throw StateError('offline');
      };

      final loaded = await CatalogBundleCache.loadOfflineFirst();

      expect(loaded.series.single.id, 'seed_series');
      expect(await CatalogBundlePersistence.hasCompletedFirestoreSync(), isFalse);
    });

    test('corrupted persisted cache does not resurrect seed after sync completed',
        () async {
      final seed = _bundle();
      final remote = _remoteWithoutDeletedSeries();
      await CatalogBundlePersistence.save(remote);
      await CatalogBundlePersistence.writeCorruptBundleForTest('not-json');

      CatalogBundleCache.loadSeedOverride = () async => seed;
      CatalogBundleCache.loadFirestoreOverride = () async {
        throw StateError('offline');
      };

      final loaded = await CatalogBundleCache.loadOfflineFirst();

      expect(loaded.series, isEmpty);
      expect(loaded.series.map((s) => s.id), isNot(contains('seed_series')));
    });

    test('Firestore timeout keeps persisted bundle on getOrLoad', () async {
      final remote = _remoteWithoutDeletedSeries();
      await CatalogBundlePersistence.save(remote);
      CatalogBundleCache.resetForTest();
      CatalogBundlePersistence.testRootOverride = tempRoot;

      CatalogBundleCache.loadSeedOverride = () async => _bundle();
      CatalogBundleCache.loadFirestoreOverride = () async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        throw StateError('timeout');
      };

      final loaded = await CatalogBundleCache.getOrLoad();

      expect(loaded.series.single.id, 'remote_series');
    });

    test('Firestore failure before first sync falls back to seed on getOrLoad',
        () async {
      final seed = _bundle();
      CatalogBundleCache.loadSeedOverride = () async => seed;
      CatalogBundleCache.loadFirestoreOverride = () async {
        throw StateError('offline');
      };

      final loaded = await CatalogBundleCache.getOrLoad();

      expect(loaded.series.single.id, 'seed_series');
    });
  });

  test('successful refresh notifies listeners and replaces in-memory bundle',
      () async {
    final remote = _remoteWithoutDeletedSeries();
    CatalogBundleCache.loadFirestoreOverride = () async => remote;

    var notified = false;
    CatalogBundleCache.onBundleReplaced = () => notified = true;

    await CatalogBundleCache.refreshFromFirestore();

    expect(notified, isTrue);
    expect(CatalogBundleCache.current?.series.single.id, 'remote_series');
    expect(await CatalogBundlePersistence.hasCompletedFirestoreSync(), isTrue);
  });

  test('refresh still notifies when persistence fails after Firestore success',
      () async {
    final remote = _remoteWithoutDeletedSeries();
    CatalogBundleCache.loadFirestoreOverride = () async => remote;
    CatalogBundleCache.persistOverride = (_) async {
      throw StateError('disk full');
    };

    var notified = false;
    CatalogBundleCache.onBundleReplaced = () => notified = true;

    await CatalogBundleCache.refreshFromFirestore();

    expect(notified, isTrue);
    expect(CatalogBundleCache.current?.series.single.id, 'remote_series');
    expect(await CatalogBundlePersistence.hasCompletedFirestoreSync(), isFalse);
  });

  test('getOrLoad notifies when Firestore succeeds even if persistence fails',
      () async {
    final remote = _remoteWithoutDeletedSeries();
    CatalogBundleCache.loadFirestoreOverride = () async => remote;
    CatalogBundleCache.persistOverride = (_) async {
      throw StateError('disk full');
    };

    var notified = false;
    CatalogBundleCache.onBundleReplaced = () => notified = true;

    final loaded = await CatalogBundleCache.getOrLoad();

    expect(notified, isTrue);
    expect(loaded.series.single.id, 'remote_series');
    expect(CatalogBundleCache.current?.series.single.id, 'remote_series');
  });

  test('refreshFromFirestore skips Firestore within catalogRefreshTtl', () async {
    CatalogBundleCache.loadFirestoreOverride = () async {
      throw StateError('should not fetch');
    };
    CatalogBundleCache.setLastFirestoreRefreshAtForTest(DateTime.now());

    final outcome = await CatalogBundleCache.refreshFromFirestore();

    expect(outcome, CatalogFirestoreRefreshResult.skippedWithinTtl);
  });

  test('refreshFromFirestore force bypasses catalogRefreshTtl', () async {
    final remote = _remoteWithoutDeletedSeries();
    CatalogBundleCache.loadFirestoreOverride = () async => remote;
    CatalogBundleCache.setLastFirestoreRefreshAtForTest(DateTime.now());

    final outcome = await CatalogBundleCache.refreshFromFirestore(force: true);

    expect(outcome, CatalogFirestoreRefreshResult.refreshed);
    expect(CatalogBundleCache.current?.series.single.id, 'remote_series');
  });

  test('consecutive refreshFromFirestore calls share one in-flight request', () async {
    var fetchCount = 0;
    CatalogBundleCache.loadFirestoreOverride = () async {
      fetchCount++;
      await Future<void>.delayed(const Duration(milliseconds: 30));
      return _remoteWithoutDeletedSeries();
    };

    final first = CatalogBundleCache.refreshFromFirestore(force: true);
    final second = CatalogBundleCache.refreshFromFirestore(force: true);

    expect(await first, CatalogFirestoreRefreshResult.refreshed);
    expect(await second, CatalogFirestoreRefreshResult.refreshed);
    expect(fetchCount, 1);
  });
}
