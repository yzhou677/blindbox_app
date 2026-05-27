import 'dart:convert';
import 'dart:io';

import 'package:blindbox_app/features/catalog/catalog_image_resolver.dart';
import 'package:blindbox_app/features/catalog/data/catalog_image_disk_cache.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Bundled in repo under assets/catalog/figures/.
const _bundledFigureKey = 'the_monsters_exciting_macaron_soymilk';

/// Minimal 1×1 PNG.
final _pngBytes = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempRoot;

  setUp(() async {
    tempRoot = await Directory.systemTemp.createTemp('catalog_img_cache_test_');
    CatalogImageDiskCache.testRootOverride = tempRoot;
    CatalogImageDiskCache.httpClientOverride = MockClient((request) async {
      return http.Response.bytes(_pngBytes, 200);
    });
    CatalogImageResolver.resetSessionCachesForTest();
    CatalogImageResolver.storageFallbackOverride = null;
    CatalogImageResolver.firebaseStorageReadyOverride = true;
    await CatalogImageResolver.ensureReady();
  });

  tearDown(() async {
    CatalogImageResolver.resetSessionCachesForTest();
    CatalogImageResolver.storageFallbackOverride = null;
    CatalogImageDiskCache.resetForTest();
    if (await tempRoot.exists()) {
      await tempRoot.delete(recursive: true);
    }
  });

  group('persistent disk cache', () {
    test('successful Storage resolve persists bytes and returns local path',
        () async {
      const imageKey = 'nommi_pinky_energy_series';
      CatalogImageResolver.getDownloadUrlOverride = (path) async {
        if (path.endsWith('.png')) {
          return 'https://example.test/$path';
        }
        return null;
      };

      final ref = await CatalogImageResolver.resolveSeriesStorageRef(imageKey);

      expect(ref, isNotNull);
      expect(ref, startsWith(tempRoot.path));
      expect(File(ref!).existsSync(), isTrue);

      final lookup = await CatalogImageDiskCache.lookupLocalPath(
        kind: CatalogImageKind.series,
        imageKey: imageKey,
      );
      expect(lookup, ref);
    });

    test('cached disk path reused without Storage extension probes', () async {
      const imageKey = 'nyota_where_moments_meet_series';
      await CatalogImageDiskCache.persistBytes(
        kind: CatalogImageKind.series,
        imageKey: imageKey,
        extension: '.png',
        bytes: _pngBytes,
      );

      CatalogImageResolver.getDownloadUrlOverride = (path) async {
        CatalogImageResolver.storageExtensionProbeCount++;
        return 'https://example.test/$path';
      };

      final first = await CatalogImageResolver.resolveSeriesStorageRef(imageKey);
      expect(first, isNotNull);
      expect(CatalogImageResolver.storageExtensionProbeCount, 0);

      CatalogImageResolver.resetSessionCachesForTest();
      CatalogImageResolver.firebaseStorageReadyOverride = true;
      CatalogImageResolver.getDownloadUrlOverride = (path) async {
        CatalogImageResolver.storageExtensionProbeCount++;
        return 'https://example.test/$path';
      };

      final second = await CatalogImageResolver.resolveSeriesStorageRef(imageKey);
      expect(second, first);
      expect(CatalogImageResolver.storageExtensionProbeCount, 0);
    });
  });

  group('session negative cache', () {
    test('missing imageKey probes extensions once per session', () async {
      const imageKey = 'missing_catalog_key_xyz';
      var probeCalls = 0;
      CatalogImageResolver.getDownloadUrlOverride = (path) async {
        probeCalls++;
        return null;
      };

      expect(
        await CatalogImageResolver.resolveFigureStorageRef(imageKey),
        isNull,
      );
      final firstPassProbes = probeCalls;
      expect(firstPassProbes, CatalogImageResolver.assetExtensions.length);

      probeCalls = 0;
      expect(
        await CatalogImageResolver.resolveFigureStorageRef(imageKey),
        isNull,
      );
      expect(probeCalls, 0);
    });

    test('repeated resolver calls do not repeat extension probing after miss',
        () async {
      const imageKey = 'another_missing_key_abc';
      CatalogImageResolver.getDownloadUrlOverride = (_) async => null;

      await CatalogImageResolver.resolveFigureStorageRef(imageKey);
      final probesAfterFirst = CatalogImageResolver.storageExtensionProbeCount;

      await CatalogImageResolver.resolveFigureStorageRef(imageKey);
      expect(
        CatalogImageResolver.storageExtensionProbeCount,
        probesAfterFirst,
      );
    });
  });

  group('bundled + storage fallback contract', () {
    test('storageFallbackEnabled=false still resolves bundled assets', () async {
      CatalogImageResolver.storageFallbackOverride = false;

      final ref = await CatalogImageResolver.resolveFigureDisplayRef(
        _bundledFigureKey,
      );

      expect(ref, 'assets/catalog/figures/$_bundledFigureKey.png');
    });

    test('valid Storage image still resolves when fallback is on', () async {
      const imageKey = 'skullpanda_petals_in_four_acts';
      CatalogImageResolver.getDownloadUrlOverride = (path) async {
        if (path.contains(imageKey) && path.endsWith('.webp')) {
          return 'https://example.test/$path';
        }
        return null;
      };

      final ref = await CatalogImageResolver.resolveSeriesStorageRef(imageKey);

      expect(ref, isNotNull);
      expect(ref, isNot(startsWith('assets/')));
    });
  });
}
