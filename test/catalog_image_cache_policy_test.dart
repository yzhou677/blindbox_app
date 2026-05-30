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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempRoot;
  final now = DateTime.utc(2026, 5, 27, 12);

  setUp(() async {
    tempRoot = await Directory.systemTemp.createTemp('catalog_cache_policy_');
    CatalogImageDiskCache.testRootOverride = tempRoot;
    CatalogImageDiskCache.testNowOverride = now;
    CatalogImageDiskCache.httpClientOverride = MockClient((_) async {
      return http.Response.bytes(_pngBytes, 200);
    });
    CatalogImageResolver.resetSessionCachesForTest();
    CatalogImageResolver.firebaseStorageReadyOverride = true;
  });

  tearDown(() async {
    CatalogImageResolver.resetSessionCachesForTest();
    CatalogImageDiskCache.resetForTest();
    if (await tempRoot.exists()) {
      await tempRoot.delete(recursive: true);
    }
  });

  group('LRU eviction', () {
    test('evicts oldest accessed entries when max bytes exceeded', () async {
      CatalogImageDiskCache.testMaxCacheBytesOverride = 200;

      await CatalogImageDiskCache.persistBytes(
        kind: CatalogImageKind.series,
        imageKey: 'oldest_series',
        extension: '.png',
        bytes: List<int>.filled(100, 1),
        writtenAt: now.subtract(const Duration(hours: 3)),
      );
      await CatalogImageDiskCache.persistBytes(
        kind: CatalogImageKind.series,
        imageKey: 'middle_series',
        extension: '.png',
        bytes: List<int>.filled(100, 2),
        writtenAt: now.subtract(const Duration(hours: 2)),
      );

      await CatalogImageDiskCache.lookup(
        kind: CatalogImageKind.series,
        imageKey: 'middle_series',
      );

      await CatalogImageDiskCache.persistBytes(
        kind: CatalogImageKind.series,
        imageKey: 'newest_series',
        extension: '.png',
        bytes: List<int>.filled(100, 3),
        writtenAt: now,
      );

      expect(await CatalogImageDiskCache.entryCount(), 2);
      expect(
        await CatalogImageDiskCache.lookupLocalPath(
          kind: CatalogImageKind.series,
          imageKey: 'oldest_series',
        ),
        isNull,
      );
      expect(
        await CatalogImageDiskCache.lookupLocalPath(
          kind: CatalogImageKind.series,
          imageKey: 'middle_series',
        ),
        isNotNull,
      );
      expect(
        await CatalogImageDiskCache.lookupLocalPath(
          kind: CatalogImageKind.series,
          imageKey: 'newest_series',
        ),
        isNotNull,
      );
      expect(await CatalogImageDiskCache.totalCacheBytes(), lessThanOrEqualTo(200));
    });
  });

  group('freshness / staleness', () {
    test('marks entries older than maxEntryAge as stale', () async {
      await CatalogImageDiskCache.persistBytes(
        kind: CatalogImageKind.figure,
        imageKey: 'stale_figure',
        extension: '.png',
        bytes: _pngBytes,
        writtenAt: now.subtract(
          CatalogImageCachePolicy.maxEntryAge + const Duration(days: 1),
        ),
      );

      final hit = await CatalogImageDiskCache.lookup(
        kind: CatalogImageKind.figure,
        imageKey: 'stale_figure',
      );

      expect(hit, isNotNull);
      expect(hit!.isStale, isTrue);
    });

    test('fresh entries are not stale', () async {
      await CatalogImageDiskCache.persistBytes(
        kind: CatalogImageKind.figure,
        imageKey: 'fresh_figure',
        extension: '.png',
        bytes: _pngBytes,
        writtenAt: now,
      );

      final hit = await CatalogImageDiskCache.lookup(
        kind: CatalogImageKind.figure,
        imageKey: 'fresh_figure',
      );

      expect(hit!.isStale, isFalse);
    });

    test('refresh cooldown prevents repeated background attempts', () async {
      await CatalogImageDiskCache.persistBytes(
        kind: CatalogImageKind.series,
        imageKey: 'cooldown_series',
        extension: '.png',
        bytes: _pngBytes,
        writtenAt: now.subtract(
          CatalogImageCachePolicy.maxEntryAge + const Duration(days: 2),
        ),
      );

      await CatalogImageDiskCache.markRefreshAttempted(
        kind: CatalogImageKind.series,
        imageKey: 'cooldown_series',
      );

      expect(
        await CatalogImageDiskCache.shouldAttemptBackgroundRefresh(
          kind: CatalogImageKind.series,
          imageKey: 'cooldown_series',
        ),
        isFalse,
      );

      CatalogImageDiskCache.testNowOverride = now.add(
        CatalogImageCachePolicy.refreshCooldown + const Duration(hours: 1),
      );

      expect(
        await CatalogImageDiskCache.shouldAttemptBackgroundRefresh(
          kind: CatalogImageKind.series,
          imageKey: 'cooldown_series',
        ),
        isTrue,
      );
    });
  });

  group('stale-while-revalidate resolver', () {
    test('serves stale disk immediately and dedupes background refresh', () async {
      CatalogImageResolver.storageFallbackOverride = true;
      const imageKey = 'stale_refresh_series';
      await CatalogImageDiskCache.persistBytes(
        kind: CatalogImageKind.series,
        imageKey: imageKey,
        extension: '.png',
        bytes: _pngBytes,
        writtenAt: now.subtract(
          CatalogImageCachePolicy.maxEntryAge + const Duration(days: 3),
        ),
      );

      var refreshProbes = 0;
      CatalogImageResolver.getDownloadUrlOverride = (path) async {
        refreshProbes++;
        if (path.endsWith('.png')) return 'https://example.test/$path';
        return null;
      };

      final first = await CatalogImageResolver.resolveSeriesStorageRef(imageKey);
      expect(first, isNotNull);
      expect(refreshProbes, 0);

      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(CatalogImageResolver.backgroundRefreshCount, 1);
      expect(refreshProbes, greaterThan(0));

      refreshProbes = 0;
      final second = await CatalogImageResolver.resolveSeriesStorageRef(imageKey);
      expect(second, first);
      expect(refreshProbes, 0);
      expect(CatalogImageResolver.backgroundRefreshCount, 1);
    });
  });
}
