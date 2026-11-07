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

    test(
      'online TimeoutException on first ext continues and can hit later ext',
      () async {
        CatalogImageResolver.getDownloadUrlOverride = (path) async {
          if (path.endsWith('.webp')) {
            throw TimeoutException('avif-equivalent first probe slow');
          }
          if (path.endsWith('.png')) {
            return 'https://example.test/$path';
          }
          return null;
        };

        final ref = await CatalogImageResolver.resolveFigureStorageRef(
          'webp_timeout_png_hit',
        );

        expect(ref, isNotNull);
        expect(CatalogImageResolver.storageExtensionProbeCount, 2);
        expect(CatalogImageResolver.storageTransportUnavailable, isFalse);
      },
    );

    test(
      'all-extension timeouts while online do not trip the global gate',
      () async {
        CatalogImageResolver.delayOverride = (_) async {};
        CatalogImageResolver.getDownloadUrlOverride = (_) async {
          throw TimeoutException('simulated storage timeout');
        };

        final ref = await CatalogImageResolver.resolveFigureStorageRef(
          'timeout_key_bbb',
        );

        expect(ref, isNull);
        // Timed-out extensions are skipped on later attempts — one walk only.
        expect(
          CatalogImageResolver.storageExtensionProbeCount,
          CatalogImageResolver.assetExtensions.length,
        );
        expect(CatalogImageResolver.storageTransportUnavailable, isFalse);
        expect(CatalogImageResolver.consecutiveTransportFailureCount, 1);
      },
    );

    test(
      'timeout while flipping offline aborts remaining extensions',
      () async {
        var online = true;
        CatalogImageResolver.isOnlineOverride = () async => online;
        CatalogImageResolver.getDownloadUrlOverride = (_) async {
          online = false;
          throw TimeoutException('link dropped mid-probe');
        };

        final ref = await CatalogImageResolver.resolveFigureStorageRef(
          'drop_mid_probe',
        );

        expect(ref, isNull);
        expect(CatalogImageResolver.storageExtensionProbeCount, 1);
        expect(CatalogImageResolver.storageTransportUnavailable, isTrue);
      },
    );

    test(
      'timeout miss does not negative-cache; later online can probe again',
      () async {
        CatalogImageResolver.delayOverride = (_) async {};
        CatalogImageResolver.getDownloadUrlOverride = (_) async {
          throw TimeoutException('down');
        };

        expect(
          await CatalogImageResolver.resolveFigureStorageRef('recover_key'),
          isNull,
        );
        expect(
          CatalogImageResolver.storageExtensionProbeCount,
          CatalogImageResolver.assetExtensions.length,
        );

        // Offline gate blocks siblings.
        CatalogImageResolver.isOnlineOverride = () async => false;
        CatalogImageResolver.storageExtensionProbeCount = 0;
        expect(
          await CatalogImageResolver.resolveFigureStorageRef('another_key'),
          isNull,
        );
        expect(CatalogImageResolver.storageExtensionProbeCount, 0);

        // Back online: clear gate and resolve via webp.
        CatalogImageResolver.isOnlineOverride = () async => true;
        CatalogImageResolver.storageExtensionProbeCount = 0;
        CatalogImageResolver.getDownloadUrlOverride = (path) async {
          if (path.endsWith('.webp')) {
            return 'https://example.test/$path';
          }
          return null;
        };

        final recovered = await CatalogImageResolver.resolveFigureStorageRef(
          'recover_key',
        );
        expect(recovered, isNotNull);
        expect(CatalogImageResolver.storageTransportUnavailable, isFalse);
        expect(CatalogImageResolver.storageExtensionProbeCount, 1);
      },
    );

    test(
      'after timeout miss, sibling keys still probe while online',
      () async {
        CatalogImageResolver.delayOverride = (_) async {};
        var calls = 0;
        CatalogImageResolver.getDownloadUrlOverride = (path) async {
          calls++;
          if (path.contains('second_key') && path.endsWith('.webp')) {
            return 'https://example.test/$path';
          }
          throw TimeoutException('down');
        };

        await CatalogImageResolver.resolveSeriesStorageRef('first_miss');
        expect(CatalogImageResolver.storageTransportUnavailable, isFalse);

        CatalogImageResolver.storageExtensionProbeCount = 0;
        final second = await CatalogImageResolver.resolveSeriesStorageRef(
          'second_key',
        );
        expect(second, isNotNull);
        expect(CatalogImageResolver.storageExtensionProbeCount, greaterThan(0));
        expect(calls, greaterThan(CatalogImageResolver.assetExtensions.length));
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
      'Firebase transport error aborts the attempt then retries, no global gate',
      () async {
        CatalogImageResolver.delayOverride = (_) async {};
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
        // One probe per attempt × (1 + retries); does not walk all extensions.
        expect(
          CatalogImageResolver.storageExtensionProbeCount,
          1 + CatalogImageResolver.maxStorageFetchRetries,
        );
        expect(CatalogImageResolver.storageTransportUnavailable, isFalse);
        expect(CatalogImageResolver.consecutiveTransportFailureCount, 1);
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
