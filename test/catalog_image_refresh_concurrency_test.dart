import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:blindbox_app/features/catalog/catalog_image_resolver.dart';
import 'package:blindbox_app/features/catalog/data/catalog_image_cache_policy.dart';
import 'package:blindbox_app/features/catalog/data/catalog_image_disk_cache.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

final _pngBytes = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
);

Future<void> _drainBackgroundRefreshes({
  required int expected,
  Duration timeout = const Duration(seconds: 2),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    if (CatalogImageResolver.backgroundRefreshCount >= expected &&
        CatalogImageResolver.activeStaleRefreshCount == 0 &&
        CatalogImageResolver.queuedStaleRefreshCount == 0) {
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 15));
  }
  fail(
    'Timed out waiting for $expected refreshes '
    '(count=${CatalogImageResolver.backgroundRefreshCount}, '
    'active=${CatalogImageResolver.activeStaleRefreshCount}, '
    'queued=${CatalogImageResolver.queuedStaleRefreshCount})',
  );
}

Future<void> _seedStaleSeries(String imageKey, DateTime writtenAt) async {
  await CatalogImageDiskCache.persistBytes(
    kind: CatalogImageKind.series,
    imageKey: imageKey,
    extension: '.png',
    bytes: _pngBytes,
    writtenAt: writtenAt,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempRoot;
  final now = DateTime.utc(2026, 5, 27, 12);

  setUp(() async {
    tempRoot = await Directory.systemTemp.createTemp('catalog_refresh_cap_');
    CatalogImageDiskCache.testRootOverride = tempRoot;
    CatalogImageDiskCache.testNowOverride = now;
    CatalogImageDiskCache.httpClientOverride = MockClient((_) async {
      return http.Response.bytes(_pngBytes, 200);
    });
    CatalogImageResolver.resetSessionCachesForTest();
    CatalogImageResolver.storageFallbackOverride = true;
    CatalogImageResolver.firebaseStorageReadyOverride = true;
    CatalogImageResolver.maxConcurrentStaleRefreshesOverride = 2;
  });

  tearDown(() async {
    await Future<void>.delayed(const Duration(milliseconds: 50));
    CatalogImageResolver.resetSessionCachesForTest();
    CatalogImageDiskCache.resetForTest();
    if (await tempRoot.exists()) {
      try {
        await tempRoot.delete(recursive: true);
      } on FileSystemException {
        // Windows may still have open cache files briefly.
      }
    }
  });

  final staleWrittenAt = now.subtract(
    CatalogImageCachePolicy.maxEntryAge + const Duration(days: 1),
  );

  group('refresh concurrency cap', () {
    test('respects max concurrent background refreshes', () async {
      final gate = Completer<void>();
      var inFlight = 0;
      var peakInFlight = 0;

      for (var i = 0; i < 5; i++) {
        await _seedStaleSeries('cap_series_$i', staleWrittenAt);
      }

      CatalogImageResolver.getDownloadUrlOverride = (path) async {
        if (!path.endsWith('.png')) return null;
        inFlight++;
        peakInFlight = inFlight > peakInFlight ? inFlight : peakInFlight;
        await gate.future;
        inFlight--;
        return 'https://example.test/$path';
      };

      for (var i = 0; i < 5; i++) {
        expect(
          await CatalogImageResolver.resolveSeriesStorageRef('cap_series_$i'),
          isNotNull,
        );
      }

      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(peakInFlight, lessThanOrEqualTo(2));
      expect(CatalogImageResolver.activeStaleRefreshCount, lessThanOrEqualTo(2));
      expect(CatalogImageResolver.queuedStaleRefreshCount, greaterThan(0));

      gate.complete();
      await _drainBackgroundRefreshes(expected: 5);
      expect(CatalogImageResolver.queuedStaleRefreshCount, 0);
    });

    test('queued refreshes eventually execute', () async {
      for (var i = 0; i < 4; i++) {
        await _seedStaleSeries('queue_series_$i', staleWrittenAt);
      }

      CatalogImageResolver.getDownloadUrlOverride = (path) async {
        if (path.endsWith('.png')) return 'https://example.test/$path';
        return null;
      };

      for (var i = 0; i < 4; i++) {
        await CatalogImageResolver.resolveSeriesStorageRef('queue_series_$i');
      }

      await _drainBackgroundRefreshes(expected: 4);
    });

    test('duplicate refresh requests for same key coalesce', () async {
      const imageKey = 'dedupe_series';
      await _seedStaleSeries(imageKey, staleWrittenAt);

      var probes = 0;
      CatalogImageResolver.getDownloadUrlOverride = (path) async {
        probes++;
        await Future<void>.delayed(const Duration(milliseconds: 30));
        if (path.endsWith('.png')) return 'https://example.test/$path';
        return null;
      };

      final first = CatalogImageResolver.resolveSeriesStorageRef(imageKey);
      final second = CatalogImageResolver.resolveSeriesStorageRef(imageKey);
      expect(await first, isNotNull);
      expect(await second, await first);

      await _drainBackgroundRefreshes(expected: 1);
      expect(probes, greaterThan(0));
    });

    test('stale disk renders immediately while refresh is queued', () async {
      const imageKey = 'immediate_stale_series';
      await _seedStaleSeries(imageKey, staleWrittenAt);

      final gate = Completer<void>();
      CatalogImageResolver.getDownloadUrlOverride = (path) async {
        if (!path.endsWith('.png')) return null;
        await gate.future;
        return 'https://example.test/$path';
      };

      final sw = Stopwatch()..start();
      final ref = await CatalogImageResolver.resolveSeriesStorageRef(imageKey);
      sw.stop();

      expect(ref, isNotNull);
      expect(File(ref!).existsSync(), isTrue);
      expect(sw.elapsed, lessThan(const Duration(milliseconds: 200)));
      expect(
        CatalogImageResolver.queuedStaleRefreshCount +
            CatalogImageResolver.activeStaleRefreshCount,
        greaterThan(0),
      );

      gate.complete();
      await _drainBackgroundRefreshes(expected: 1);
    });
  });
}
