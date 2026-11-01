import 'dart:async';

import 'package:blindbox_app/features/catalog/application/catalog_bundle_cache.dart';
import 'package:blindbox_app/features/catalog/catalog_bundle.dart';
import 'package:blindbox_app/features/catalog/data/catalog_bundle_codec.dart';
import 'package:blindbox_app/features/catalog/data/catalog_bundle_merge.dart';
import 'package:blindbox_app/features/catalog/models/catalog_brand.dart';
import 'package:blindbox_app/features/catalog/models/catalog_figure.dart';
import 'package:blindbox_app/features/catalog/models/catalog_ip.dart';
import 'package:blindbox_app/features/catalog/models/catalog_series.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

CatalogSeedBundle _base({
  String seriesName = 'Local',
  String? imageVersion,
}) => CatalogSeedBundle(
  brands: [
    CatalogBrand(
      id: 'b',
      displayName: 'B',
      updatedAt: DateTime.utc(2026, 1, 1),
    ),
  ],
  ips: [
    CatalogIp(
      id: 'ip',
      brandId: 'b',
      displayName: 'IP',
      updatedAt: DateTime.utc(2026, 1, 1),
    ),
  ],
  series: [
    CatalogSeries(
      id: 's1',
      brandId: 'b',
      ipId: 'ip',
      displayName: seriesName,
      releaseDate: '2026-01-01',
      isBlindBox: true,
      imageKey: 's1',
      imageVersion: imageVersion,
      updatedAt: DateTime.utc(2026, 1, 1),
    ),
  ],
  figures: [
    CatalogFigure(
      id: 'f1',
      seriesId: 's1',
      brandId: 'b',
      ipId: 'ip',
      displayName: 'Fig',
      isSecret: false,
      sortOrder: 1,
      imageKey: 'f1',
      imageVersion: imageVersion,
      updatedAt: DateTime.utc(2026, 1, 1),
      alternativeImages: [
        CatalogAlternativeImage(
          imageKey: 'f1_alt',
          variant: 'box',
          imageVersion: imageVersion,
        ),
      ],
    ),
  ],
);

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    CatalogBundleCache.resetForTest();
  });

  tearDown(CatalogBundleCache.resetForTest);

  group('mergeCatalogSeedBundle', () {
    test('upserts changed entities and keeps omitted ids', () {
      final base = _base();
      final delta = CatalogSeedBundle(
        brands: const [],
        ips: const [],
        series: [
          CatalogSeries(
            id: 's1',
            brandId: 'b',
            ipId: 'ip',
            displayName: 'Updated',
            releaseDate: '2026-01-01',
            isBlindBox: true,
            imageKey: 's1',
            imageVersion: 'newMd5',
            updatedAt: DateTime.utc(2026, 3, 1),
          ),
          CatalogSeries(
            id: 's2',
            brandId: 'b',
            ipId: 'ip',
            displayName: 'New',
            releaseDate: '2026-02-01',
            isBlindBox: true,
            imageKey: 's2',
            updatedAt: DateTime.utc(2026, 3, 1),
          ),
        ],
        figures: const [],
      );

      final merged = mergeCatalogSeedBundle(base, delta);

      expect(merged.series.map((s) => s.id), ['s2', 's1']);
      expect(merged.series.firstWhere((s) => s.id == 's1').displayName, 'Updated');
      expect(merged.series.firstWhere((s) => s.id == 's1').imageVersion, 'newMd5');
      expect(merged.figures.single.id, 'f1');
      expect(merged.brands.single.id, 'b');
    });
  });

  group('CatalogBundleCodec v1/v2', () {
    test('decodes legacy schemaVersion 1 without sync fields', () {
      const raw = '''
{
  "schemaVersion": 1,
  "syncedAt": "2026-01-01T00:00:00.000Z",
  "brands": [{"id":"b","displayName":"B"}],
  "ips": [{"id":"ip","brandId":"b","displayName":"IP"}],
  "series": [{
    "id":"s1","brandId":"b","ipId":"ip","displayName":"S",
    "releaseDate":"2026-01-01","isBlindBox":true,"imageKey":"s1"
  }],
  "figures": [{
    "id":"f1","seriesId":"s1","brandId":"b","ipId":"ip",
    "displayName":"F","isSecret":false,"sortOrder":1,"imageKey":"f1"
  }]
}
''';
      final decoded = CatalogBundleCodec.tryDecode(raw);
      expect(decoded, isNotNull);
      expect(decoded!.series.single.imageVersion, isNull);
      expect(decoded.series.single.updatedAt, isNull);
      expect(decoded.figures.single.imageVersion, isNull);
      expect(decoded.figures.single.alternativeImages, isEmpty);
    });

    test('round-trips imageVersion including alternativeImages', () {
      final original = _base(imageVersion: 'abcMd5');
      final decoded = CatalogBundleCodec.tryDecode(
        CatalogBundleCodec.encode(original),
      );
      expect(decoded, isNotNull);
      expect(decoded!.series.single.imageVersion, 'abcMd5');
      expect(decoded.figures.single.imageVersion, 'abcMd5');
      expect(
        decoded.figures.single.alternativeImages.single.imageVersion,
        'abcMd5',
      );
      expect(CatalogBundleCodec.schemaVersion, 2);
    });

    test('missing updatedAt and imageVersion decode as null', () {
      final figure = CatalogFigure.fromJson({
        'id': 'f1',
        'seriesId': 's1',
        'brandId': 'b',
        'ipId': 'ip',
        'displayName': 'F',
        'isSecret': false,
        'sortOrder': 1,
        'imageKey': 'f1',
        'alternativeImages': [
          {'imageKey': 'alt', 'variant': 'box'},
        ],
      });
      expect(figure.imageVersion, isNull);
      expect(figure.updatedAt, isNull);
      expect(figure.alternativeImages.single.imageVersion, isNull);
    });
  });

  group('CatalogBundleCache incremental sync', () {
    Future<void> primeSynced({
      required CatalogSeedBundle local,
      required DateTime lastSync,
      required DateTime lastFull,
    }) async {
      CatalogBundleCache.prime(local);
      CatalogBundleCache.setLastSyncAtMemoryForTest(lastSync);
      CatalogBundleCache.setLastFirestoreRefreshAtForTest(lastFull);
      CatalogBundleCache.loadPersistedOverride = () async => local;
      CatalogBundleCache.persistOverride = (_) async {};
      CatalogBundleCache.saveLastSyncAtOverride = (_) async {};
      CatalogBundleCache.saveLastFullSyncAtOverride = (_) async {};
      CatalogBundleCache.loadLastSyncAtOverride = () async => lastSync;
      CatalogBundleCache.loadLastFullSyncAtOverride = () async => lastFull;
    }

    test('meta unchanged skips collection queries', () async {
      final now = DateTime.now().toUtc();
      final lastSync = now.subtract(const Duration(minutes: 5));
      await primeSynced(
        local: _base(),
        lastSync: lastSync,
        lastFull: now.subtract(const Duration(hours: 1)),
      );

      var fullCount = 0;
      var deltaCount = 0;
      CatalogBundleCache.loadFirestoreOverride = () async {
        fullCount++;
        return _base();
      };
      CatalogBundleCache.loadDeltaOverride = (_) async {
        deltaCount++;
        return const CatalogSeedBundle(
          brands: [],
          ips: [],
          series: [],
          figures: [],
        );
      };
      CatalogBundleCache.loadMetaOverride = () async => lastSync;

      final outcome = await CatalogBundleCache.refreshFromFirestore();

      expect(outcome, CatalogFirestoreRefreshResult.unchanged);
      expect(fullCount, 0);
      expect(deltaCount, 0);
    });

    test('meta newer merges delta and advances lastSyncAt', () async {
      final now = DateTime.now().toUtc();
      final lastSync = now.subtract(const Duration(hours: 2));
      final metaAt = now.subtract(const Duration(minutes: 1));
      await primeSynced(
        local: _base(),
        lastSync: lastSync,
        lastFull: now.subtract(const Duration(hours: 3)),
      );

      var fullCount = 0;
      DateTime? deltaSince;
      DateTime? savedSync;
      CatalogBundleCache.loadFirestoreOverride = () async {
        fullCount++;
        return _base();
      };
      CatalogBundleCache.loadDeltaOverride = (since) async {
        deltaSince = since;
        return CatalogSeedBundle(
          brands: const [],
          ips: const [],
          series: [
            CatalogSeries(
              id: 's1',
              brandId: 'b',
              ipId: 'ip',
              displayName: 'Patched',
              releaseDate: '2026-01-01',
              isBlindBox: true,
              imageKey: 's1',
              imageVersion: 'v2',
              updatedAt: metaAt,
            ),
          ],
          figures: const [],
        );
      };
      CatalogBundleCache.loadMetaOverride = () async => metaAt;
      CatalogBundleCache.saveLastSyncAtOverride = (at) async {
        savedSync = at;
      };

      final outcome = await CatalogBundleCache.refreshFromFirestore();

      expect(outcome, CatalogFirestoreRefreshResult.refreshed);
      expect(fullCount, 0);
      expect(deltaSince, lastSync);
      expect(savedSync, metaAt);
      expect(CatalogBundleCache.lastSyncAtMemoryForTest, metaAt);
      expect(CatalogBundleCache.current?.series.single.displayName, 'Patched');
      expect(CatalogBundleCache.current?.series.single.imageVersion, 'v2');
      expect(CatalogBundleCache.current?.figures.single.id, 'f1');
    });

    test('first install without cache forces full get', () async {
      var fullCount = 0;
      var deltaCount = 0;
      CatalogBundleCache.loadPersistedOverride = () async => null;
      CatalogBundleCache.persistOverride = (_) async {};
      CatalogBundleCache.saveLastSyncAtOverride = (_) async {};
      CatalogBundleCache.saveLastFullSyncAtOverride = (_) async {};
      CatalogBundleCache.loadMetaOverride = () async => DateTime.utc(2026, 5, 1);
      CatalogBundleCache.loadFirestoreOverride = () async {
        fullCount++;
        return _base(seriesName: 'Remote');
      };
      CatalogBundleCache.loadDeltaOverride = (_) async {
        deltaCount++;
        return const CatalogSeedBundle(
          brands: [],
          ips: [],
          series: [],
          figures: [],
        );
      };

      await CatalogBundleCache.loadOfflineFirst();
      final outcome = await CatalogBundleCache.refreshFromFirestore();

      expect(outcome, CatalogFirestoreRefreshResult.refreshed);
      expect(fullCount, greaterThanOrEqualTo(1));
      expect(deltaCount, 0);
      expect(CatalogBundleCache.current?.series.single.displayName, 'Remote');
    });

    test('incremental failure falls back to full get', () async {
      final now = DateTime.now().toUtc();
      final lastSync = now.subtract(const Duration(hours: 2));
      final metaAt = now.subtract(const Duration(minutes: 1));
      await primeSynced(
        local: _base(),
        lastSync: lastSync,
        lastFull: now.subtract(const Duration(hours: 3)),
      );

      var fullCount = 0;
      CatalogBundleCache.loadMetaOverride = () async => metaAt;
      CatalogBundleCache.loadDeltaOverride = (_) async {
        throw StateError('delta query failed');
      };
      CatalogBundleCache.loadFirestoreOverride = () async {
        fullCount++;
        return _base(seriesName: 'Full');
      };

      final outcome = await CatalogBundleCache.refreshFromFirestore();

      expect(outcome, CatalogFirestoreRefreshResult.refreshed);
      expect(fullCount, 1);
      expect(CatalogBundleCache.current?.series.single.displayName, 'Full');
    });

    test('full reconcile after 24h even when meta unchanged', () async {
      final now = DateTime.now().toUtc();
      final lastSync = now.subtract(const Duration(hours: 1));
      await primeSynced(
        local: _base(),
        lastSync: lastSync,
        lastFull: now.subtract(const Duration(hours: 25)),
      );

      var fullCount = 0;
      var deltaCount = 0;
      CatalogBundleCache.loadMetaOverride = () async => lastSync;
      CatalogBundleCache.loadDeltaOverride = (_) async {
        deltaCount++;
        return const CatalogSeedBundle(
          brands: [],
          ips: [],
          series: [],
          figures: [],
        );
      };
      CatalogBundleCache.loadFirestoreOverride = () async {
        fullCount++;
        return _base(seriesName: 'Reconciled');
      };

      final outcome = await CatalogBundleCache.refreshFromFirestore();

      expect(outcome, CatalogFirestoreRefreshResult.refreshed);
      expect(fullCount, 1);
      expect(deltaCount, 0);
      expect(
        CatalogBundleCache.current?.series.single.displayName,
        'Reconciled',
      );
    });

    test('meta listener triggers refresh when watermark advances', () async {
      final now = DateTime.now().toUtc();
      final lastSync = now.subtract(const Duration(hours: 2));
      final metaAt = now.subtract(const Duration(minutes: 1));
      await primeSynced(
        local: _base(),
        lastSync: lastSync,
        lastFull: now.subtract(const Duration(hours: 3)),
      );

      final controller = StreamController<DateTime?>.broadcast();
      CatalogBundleCache.metaSnapshotStreamOverride = () => controller.stream;
      CatalogBundleCache.ensureFirebaseForMetaListenerOverride = () async {};

      var deltaCount = 0;
      CatalogBundleCache.loadMetaOverride = () async => metaAt;
      CatalogBundleCache.loadDeltaOverride = (_) async {
        deltaCount++;
        return CatalogSeedBundle(
          brands: const [],
          ips: const [],
          series: [
            CatalogSeries(
              id: 's1',
              brandId: 'b',
              ipId: 'ip',
              displayName: 'FromListener',
              releaseDate: '2026-01-01',
              isBlindBox: true,
              imageKey: 's1',
              updatedAt: metaAt,
            ),
          ],
          figures: const [],
        );
      };
      CatalogBundleCache.loadFirestoreOverride = () async {
        fail('full get should not run');
      };

      await CatalogBundleCache.startMetaListener();
      controller.add(metaAt);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await CatalogBundleCache.stopMetaListener();
      await controller.close();

      expect(deltaCount, 1);
      expect(
        CatalogBundleCache.current?.series.single.displayName,
        'FromListener',
      );
    });

    test('force refresh bypasses meta short-circuit', () async {
      final now = DateTime.now().toUtc();
      final lastSync = now.subtract(const Duration(minutes: 5));
      await primeSynced(
        local: _base(),
        lastSync: lastSync,
        lastFull: now,
      );

      var fullCount = 0;
      CatalogBundleCache.loadMetaOverride = () async => lastSync;
      CatalogBundleCache.loadFirestoreOverride = () async {
        fullCount++;
        return _base(seriesName: 'Forced');
      };
      CatalogBundleCache.loadDeltaOverride = (_) async {
        fail('delta should not run on force');
      };

      final outcome = await CatalogBundleCache.refreshFromFirestore(force: true);

      expect(outcome, CatalogFirestoreRefreshResult.refreshed);
      expect(fullCount, 1);
      expect(CatalogBundleCache.current?.series.single.displayName, 'Forced');
    });
  });
}
