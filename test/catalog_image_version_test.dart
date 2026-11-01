import 'dart:convert';
import 'dart:io';

import 'package:blindbox_app/features/catalog/application/catalog_bundle_cache.dart';
import 'package:blindbox_app/features/catalog/catalog_bundle.dart';
import 'package:blindbox_app/features/catalog/catalog_image_resolver.dart';
import 'package:blindbox_app/features/catalog/data/catalog_image_disk_cache.dart';
import 'package:blindbox_app/features/catalog/data/catalog_image_version.dart';
import 'package:blindbox_app/features/catalog/models/catalog_brand.dart';
import 'package:blindbox_app/features/catalog/models/catalog_figure.dart';
import 'package:blindbox_app/features/catalog/models/catalog_ip.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

final _pngBytes = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
);

/// Realistic Storage md5Hash with `/`, `+`, `=`.
const _md5V1 = 'abc/def+ghi=';
const _md5V2 = 'xyz/uvw+rst=';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CatalogImageVersion helpers', () {
    test('appendQueryParam encodes / + = via encodeQueryComponent', () {
      const base =
          'https://firebasestorage.googleapis.com/v0/b/x/o/a.png?alt=media&token=t';
      final out = CatalogImageVersion.appendQueryParam(base, _md5V1);
      expect(out, contains('&v='));
      expect(out, isNot(contains('&v=abc/def')));
      expect(out, contains(Uri.encodeQueryComponent(_md5V1)));
      expect(
        out,
        'https://firebasestorage.googleapis.com/v0/b/x/o/a.png'
        '?alt=media&token=t&v=${Uri.encodeQueryComponent(_md5V1)}',
      );
    });

    test('appendQueryParam uses ? when URL has no query', () {
      final out = CatalogImageVersion.appendQueryParam(
        'https://example.test/a.png',
        'v1',
      );
      expect(out, 'https://example.test/a.png?v=v1');
    });

    test('appendQueryParam and networkCacheKey no-op when version empty', () {
      const url = 'https://example.test/a.png?token=1';
      expect(CatalogImageVersion.appendQueryParam(url, null), url);
      expect(CatalogImageVersion.appendQueryParam(url, '  '), url);
      expect(CatalogImageVersion.networkCacheKey(url, null), url);
    });

    test('diskEntryKey includes version only when present', () {
      expect(
        CatalogImageVersion.diskEntryKey(
          kind: CatalogImageKind.series,
          imageKey: 's1',
          imageVersion: null,
        ),
        'catalog/series/s1',
      );
      expect(
        CatalogImageVersion.diskEntryKey(
          kind: CatalogImageKind.figure,
          imageKey: 'f1',
          imageVersion: _md5V1,
        ),
        'catalog/figures/f1#$_md5V1',
      );
    });

    test('networkCacheKey appends #version', () {
      expect(
        CatalogImageVersion.networkCacheKey('https://x/a.png', _md5V1),
        'https://x/a.png#$_md5V1',
      );
    });
  });

  group('disk cache version bust', () {
    late Directory tempRoot;
    late List<Uri> requested;

    setUp(() async {
      tempRoot = await Directory.systemTemp.createTemp('catalog_img_ver_');
      requested = <Uri>[];
      CatalogImageDiskCache.testRootOverride = tempRoot;
      CatalogImageDiskCache.httpClientOverride = MockClient((req) async {
        requested.add(req.url);
        return http.Response.bytes(_pngBytes, 200);
      });
      CatalogImageResolver.resetSessionCachesForTest();
      CatalogImageResolver.firebaseStorageReadyOverride = true;
      CatalogBundleCache.resetForTest();
    });

    tearDown(() async {
      CatalogImageResolver.resetSessionCachesForTest();
      CatalogImageDiskCache.resetForTest();
      CatalogBundleCache.resetForTest();
      if (await tempRoot.exists()) {
        await tempRoot.delete(recursive: true);
      }
    });

    test('same imageKey new imageVersion misses and purges old file', () async {
      const imageKey = 'series_cover_a';
      final pathV1 = await CatalogImageDiskCache.persistBytes(
        kind: CatalogImageKind.series,
        imageKey: imageKey,
        extension: '.png',
        bytes: _pngBytes,
        imageVersion: _md5V1,
      );
      expect(pathV1, isNotNull);
      expect(File(pathV1!).existsSync(), isTrue);
      expect(await CatalogImageDiskCache.entryCount(), 1);

      final hitV1 = await CatalogImageDiskCache.lookup(
        kind: CatalogImageKind.series,
        imageKey: imageKey,
        imageVersion: _md5V1,
      );
      expect(hitV1?.localPath, pathV1);

      // Different version → miss against v1 entry.
      expect(
        await CatalogImageDiskCache.lookup(
          kind: CatalogImageKind.series,
          imageKey: imageKey,
          imageVersion: _md5V2,
        ),
        isNull,
      );

      final pathV2 = await CatalogImageDiskCache.persistBytes(
        kind: CatalogImageKind.series,
        imageKey: imageKey,
        extension: '.png',
        bytes: List<int>.from(_pngBytes)..add(1),
        imageVersion: _md5V2,
      );
      expect(pathV2, isNotNull);
      expect(pathV2, isNot(pathV1));
      expect(File(pathV1).existsSync(), isFalse);
      expect(File(pathV2!).existsSync(), isTrue);
      expect(await CatalogImageDiskCache.entryCount(), 1);
      expect(
        await CatalogImageDiskCache.entryKeysForTest(),
        ['catalog/series/$imageKey#$_md5V2'],
      );
    });

    test('persistFromUrl requests URL with encoded v= param', () async {
      const imageKey = 'fig_a';
      const raw =
          'https://firebasestorage.googleapis.com/v0/b/bucket/o/x.png'
          '?alt=media&token=tok';
      final path = await CatalogImageDiskCache.persistFromUrl(
        kind: CatalogImageKind.figure,
        imageKey: imageKey,
        downloadUrl: raw,
        extension: '.png',
        imageVersion: _md5V1,
      );
      expect(path, isNotNull);
      expect(requested, hasLength(1));
      expect(requested.single.queryParameters['v'], _md5V1);
      expect(
        requested.single.toString(),
        contains(Uri.encodeQueryComponent(_md5V1)),
      );
    });

    test('null imageVersion keeps legacy key and filename', () async {
      const imageKey = 'legacy_key';
      final path = await CatalogImageDiskCache.persistBytes(
        kind: CatalogImageKind.figure,
        imageKey: imageKey,
        extension: '.png',
        bytes: _pngBytes,
      );
      expect(path, endsWith('/figures/$imageKey.png'));
      expect(
        await CatalogImageDiskCache.entryKeysForTest(),
        ['catalog/figures/$imageKey'],
      );
      final hit = await CatalogImageDiskCache.lookup(
        kind: CatalogImageKind.figure,
        imageKey: imageKey,
      );
      expect(hit?.localPath, path);
    });

    test('resolver re-downloads when imageVersion changes', () async {
      const imageKey = 'remote_series';
      var downloads = 0;
      CatalogImageResolver.getDownloadUrlOverride = (path) async {
        if (!path.endsWith('.png')) return null;
        downloads++;
        return 'https://example.test/$path?token=1';
      };

      final first = await CatalogImageResolver.resolveSeriesStorageRef(
        imageKey,
        imageVersion: _md5V1,
      );
      expect(first, isNotNull);
      expect(downloads, 1);

      CatalogImageResolver.resetSessionCachesForTest();
      CatalogImageResolver.firebaseStorageReadyOverride = true;
      CatalogImageResolver.getDownloadUrlOverride = (path) async {
        if (!path.endsWith('.png')) return null;
        downloads++;
        return 'https://example.test/$path?token=1';
      };

      final second = await CatalogImageResolver.resolveSeriesStorageRef(
        imageKey,
        imageVersion: _md5V1,
      );
      expect(second, first);
      expect(downloads, 1);

      CatalogImageResolver.resetSessionCachesForTest();
      CatalogImageResolver.firebaseStorageReadyOverride = true;
      CatalogImageResolver.getDownloadUrlOverride = (path) async {
        if (!path.endsWith('.png')) return null;
        downloads++;
        return 'https://example.test/$path?token=1';
      };

      final third = await CatalogImageResolver.resolveSeriesStorageRef(
        imageKey,
        imageVersion: _md5V2,
      );
      expect(third, isNotNull);
      expect(third, isNot(first));
      expect(downloads, 2);
      expect(File(first!).existsSync(), isFalse);
    });

    test('lookupImageVersion finds figure alternativeImages', () {
      CatalogBundleCache.prime(
        CatalogSeedBundle(
          brands: const [CatalogBrand(id: 'b', displayName: 'B')],
          ips: const [CatalogIp(id: 'ip', brandId: 'b', displayName: 'IP')],
          series: const [],
          figures: [
            CatalogFigure(
              id: 'f1',
              seriesId: 's1',
              brandId: 'b',
              ipId: 'ip',
              displayName: 'F',
              isSecret: false,
              sortOrder: 1,
              imageKey: 'f1',
              imageVersion: 'primaryMd5',
              alternativeImages: const [
                CatalogAlternativeImage(
                  imageKey: 'f1_box',
                  variant: 'box',
                  imageVersion: 'alt/Md5+==',
                ),
              ],
            ),
          ],
        ),
      );

      expect(
        CatalogImageResolver.lookupImageVersion(
          kind: CatalogImageKind.figure,
          imageKey: 'f1',
        ),
        'primaryMd5',
      );
      expect(
        CatalogImageResolver.lookupImageVersion(
          kind: CatalogImageKind.figure,
          imageKey: 'f1_box',
        ),
        'alt/Md5+==',
      );
    });
  });
}
