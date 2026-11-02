import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:blindbox_app/features/catalog/catalog_image_resolver.dart';
import 'package:blindbox_app/features/catalog/data/catalog_image_disk_cache.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Minimal 1×1 PNG.
final _pngBytes = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempRoot;

  setUp(() async {
    tempRoot = await Directory.systemTemp.createTemp(
      'catalog_img_offline_fail_fast_',
    );
    CatalogImageDiskCache.testRootOverride = tempRoot;
    CatalogImageDiskCache.httpClientOverride = MockClient((request) async {
      return http.Response.bytes(_pngBytes, 200);
    });
    CatalogImageResolver.resetSessionCachesForTest();
    CatalogImageResolver.storageFallbackOverride = true;
    CatalogImageResolver.firebaseStorageReadyOverride = true;
    CatalogImageResolver.isOnlineOverride = () async => true;
  });

  tearDown(() async {
    CatalogImageResolver.resetSessionCachesForTest();
    CatalogImageResolver.storageFallbackOverride = null;
    CatalogImageDiskCache.resetForTest();
    if (await tempRoot.exists()) {
      await tempRoot.delete(recursive: true);
    }
  });

  group('offline / transport fail-fast', () {
    test('known offline skips Storage probes entirely', () async {
      CatalogImageResolver.isOnlineOverride = () async => false;

      var probes = 0;
      CatalogImageResolver.getDownloadUrlOverride = (_) async {
        probes++;
        return 'https://example.test/should-not-run';
      };

      final ref = await CatalogImageResolver.resolveFigureDisplayRef(
        'offline_key_aaa',
      );

      expect(ref, isNull);
      expect(probes, 0);
      expect(CatalogImageResolver.storageExtensionProbeCount, 0);
      expect(CatalogImageResolver.storageTransportUnavailable, isTrue);
    });

    test('TimeoutException stops after first extension probe', () async {
      CatalogImageResolver.getDownloadUrlOverride = (_) async {
        throw TimeoutException('simulated storage timeout');
      };

      final ref = await CatalogImageResolver.resolveFigureStorageRef(
        'timeout_key_bbb',
      );

      expect(ref, isNull);
      expect(CatalogImageResolver.storageExtensionProbeCount, 1);
      expect(CatalogImageResolver.storageTransportUnavailable, isTrue);
    });

    test(
      'timeout does not negative-cache the key; later online can probe again',
      () async {
        var mode = 'timeout';
        CatalogImageResolver.getDownloadUrlOverride = (path) async {
          if (mode == 'timeout') {
            throw TimeoutException('down');
          }
          if (path.endsWith('.webp')) {
            return 'https://example.test/$path';
          }
          return null;
        };

        expect(
          await CatalogImageResolver.resolveFigureStorageRef('recover_key'),
          isNull,
        );
        expect(CatalogImageResolver.storageExtensionProbeCount, 1);

        // Still offline: subsequent keys must not walk extensions.
        CatalogImageResolver.isOnlineOverride = () async => false;
        final probesAfterTimeout =
            CatalogImageResolver.storageExtensionProbeCount;
        expect(
          await CatalogImageResolver.resolveFigureStorageRef('another_key'),
          isNull,
        );
        expect(
          CatalogImageResolver.storageExtensionProbeCount,
          probesAfterTimeout,
        );

        // Back online: clear gate and resolve the original key.
        CatalogImageResolver.isOnlineOverride = () async => true;
        mode = 'ok';
        CatalogImageResolver.storageExtensionProbeCount = 0;

        final recovered = await CatalogImageResolver.resolveFigureStorageRef(
          'recover_key',
        );
        expect(recovered, isNotNull);
        expect(CatalogImageResolver.storageTransportUnavailable, isFalse);
        expect(
          CatalogImageResolver.storageExtensionProbeCount,
          lessThan(CatalogImageResolver.assetExtensions.length),
        );
      },
    );

    test(
      'after transport failure, sibling keys skip probes while offline',
      () async {
        CatalogImageResolver.getDownloadUrlOverride = (_) async {
          throw TimeoutException('down');
        };

        await CatalogImageResolver.resolveSeriesStorageRef('first_miss');
        expect(CatalogImageResolver.storageExtensionProbeCount, 1);

        CatalogImageResolver.isOnlineOverride = () async => false;
        CatalogImageResolver.storageExtensionProbeCount = 0;

        for (final key in ['feed_a', 'feed_b', 'feed_c']) {
          expect(
            await CatalogImageResolver.resolveSeriesStorageRef(key),
            isNull,
          );
        }
        expect(CatalogImageResolver.storageExtensionProbeCount, 0);
      },
    );

    test(
      'object-not-found still probes every extension (not a transport fail)',
      () async {
        CatalogImageResolver.getDownloadUrlOverride = (_) async => null;

        final ref = await CatalogImageResolver.resolveFigureStorageRef(
          'truly_missing_key',
        );

        expect(ref, isNull);
        expect(
          CatalogImageResolver.storageExtensionProbeCount,
          CatalogImageResolver.assetExtensions.length,
        );
        expect(CatalogImageResolver.storageTransportUnavailable, isFalse);

        // Second call uses session missing cache — zero probes.
        CatalogImageResolver.storageExtensionProbeCount = 0;
        expect(
          await CatalogImageResolver.resolveFigureStorageRef(
            'truly_missing_key',
          ),
          isNull,
        );
        expect(CatalogImageResolver.storageExtensionProbeCount, 0);
      },
    );

    test('disk cache hit still works while transport is unavailable', () async {
      const imageKey = 'cached_while_offline';
      await CatalogImageDiskCache.persistBytes(
        kind: CatalogImageKind.figure,
        imageKey: imageKey,
        extension: '.png',
        bytes: _pngBytes,
      );

      CatalogImageResolver.isOnlineOverride = () async => false;
      CatalogImageResolver.getDownloadUrlOverride = (_) async {
        fail('Storage must not be probed on disk hit');
      };

      final ref = await CatalogImageResolver.resolveFigureDisplayRef(imageKey);
      expect(ref, isNotNull);
      expect(ref, startsWith(tempRoot.path));
      expect(CatalogImageResolver.storageExtensionProbeCount, 0);
    });

    test(
      'Firebase transport error fails fast without walking extensions',
      () async {
        CatalogImageResolver.getDownloadUrlOverride = (_) async {
          throw FirebaseException(
            plugin: 'firebase_storage',
            code: 'unavailable',
            message: 'network unreachable',
          );
        };

        final ref = await CatalogImageResolver.resolveFigureStorageRef(
          'transport_err_key',
        );

        expect(ref, isNull);
        expect(CatalogImageResolver.storageExtensionProbeCount, 1);
        expect(CatalogImageResolver.storageTransportUnavailable, isTrue);
      },
    );

    test('displayRef path respects offline skip', () async {
      CatalogImageResolver.isOnlineOverride = () async => false;
      CatalogImageResolver.getDownloadUrlOverride = (_) async {
        fail('should not probe');
      };

      expect(
        await CatalogImageResolver.resolveSeriesDisplayRef('series_offline'),
        isNull,
      );
      expect(CatalogImageResolver.storageExtensionProbeCount, 0);
    });
  });
}
