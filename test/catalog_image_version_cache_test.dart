import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:blindbox_app/features/catalog/application/catalog_bundle_cache.dart';
import 'package:blindbox_app/features/catalog/catalog_bundle.dart';
import 'package:blindbox_app/features/catalog/catalog_image_resolver.dart';
import 'package:blindbox_app/features/catalog/data/catalog_image_disk_cache.dart';
import 'package:blindbox_app/features/catalog/models/catalog_figure.dart';
import 'package:blindbox_app/features/catalog/presentation/catalog_image_display.dart';
import 'package:blindbox_app/features/collectible_relationship/application/collectible_relationship_providers.dart';
import 'package:blindbox_app/shared/widgets/catalog_image_from_key.dart';
import 'package:blindbox_app/shared/widgets/catalog_resolved_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

final _pngBytes = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
);

CatalogFigure _figure(String imageKey, String imageVersion) {
  return CatalogFigure(
    id: imageKey,
    seriesId: 'series_a',
    brandId: 'pop_mart',
    ipId: 'dimoo',
    displayName: 'Fig',
    isSecret: false,
    sortOrder: 1,
    imageKey: imageKey,
    imageVersion: imageVersion,
  );
}

CatalogResolvedImage _resolved(WidgetTester tester) {
  return tester.widget<CatalogResolvedImage>(
    find.byType(CatalogResolvedImage),
  );
}

Future<void> _pumpUntil(WidgetTester tester, Completer completer) async {
  while (!completer.isCompleted) {
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();
  }
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempRoot;

  setUp(() async {
    tempRoot = await Directory.systemTemp.createTemp('catalog_ver_cache_');
    CatalogImageDiskCache.testRootOverride = tempRoot;
    CatalogImageDiskCache.httpClientOverride = MockClient((request) async {
      return http.Response.bytes(_pngBytes, 200);
    });
    CatalogImageResolver.resetSessionCachesForTest();
    CatalogImageResolver.storageFallbackOverride = true;
    CatalogImageResolver.firebaseStorageReadyOverride = true;
    CatalogImageResolver.isOnlineOverride = () async => true;
    CatalogBundleCache.resetForTest();
    catalogImageFromKeyDebugOnResolveStart = null;
    catalogImageFromKeyDebugOnResolveApplied = null;
  });

  tearDown(() async {
    catalogImageFromKeyDebugOnResolveStart = null;
    catalogImageFromKeyDebugOnResolveApplied = null;
    CatalogBundleCache.resetForTest();
    CatalogImageResolver.resetSessionCachesForTest();
    CatalogImageResolver.storageFallbackOverride = null;
    CatalogImageDiskCache.resetForTest();
    if (await tempRoot.exists()) {
      try {
        await tempRoot.delete(recursive: true);
      } on FileSystemException {
        // Windows may hold open image files.
      }
    }
  });

  testWidgets(
    'imageVersion change shows new art; failed refresh keeps old art',
    (tester) async {
      const imageKey = 'swr_version';
      CatalogImageResolver.getDownloadUrlOverride = (path) async {
        if (path.endsWith('.webp')) {
          return 'https://example.test/$path?v=1';
        }
        return null;
      };

      final appliedV1 = Completer<void>();
      catalogImageFromKeyDebugOnResolveApplied = (key, version) {
        if (key == imageKey && version == 'v1' && !appliedV1.isCompleted) {
          appliedV1.complete();
        }
      };

      CatalogBundleCache.prime(
        CatalogSeedBundle(
          brands: const [],
          ips: const [],
          series: const [],
          figures: [_figure(imageKey, 'v1')],
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            relationshipHintForCatalogSeriesProvider.overrideWith(
              (ref, _) => null,
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 120,
                height: 120,
                child: CatalogImageFromKey(
                  imageKey: imageKey,
                  name: 'Fig',
                  seedKey: imageKey,
                  displayMode: CatalogImageDisplayMode.figureThumb,
                ),
              ),
            ),
          ),
        ),
      );
      await _pumpUntil(tester, appliedV1);
      final old = _resolved(tester);
      expect(old.imageVersion, 'v1');
      expect(File(old.imageRef).existsSync(), isTrue);
      final oldRef = old.imageRef;

      final pending = Completer<String?>();
      final v2Entered = Completer<void>();
      CatalogImageResolver.getDownloadUrlOverride = (path) async {
        if (!path.endsWith('.webp')) return null;
        if (!v2Entered.isCompleted) v2Entered.complete();
        return pending.future;
      };

      CatalogBundleCache.prime(
        CatalogSeedBundle(
          brands: const [],
          ips: const [],
          series: const [],
          figures: [_figure(imageKey, 'v2')],
        ),
      );
      CatalogBundleCache.triggerBundleReplacedForTest();
      await tester.pump();
      await _pumpUntil(tester, v2Entered);

      // Still showing old art while v2 loads.
      final mid = _resolved(tester);
      expect(mid.imageRef, oldRef);
      expect(mid.imageVersion, 'v1');
      expect(File(mid.imageRef).existsSync(), isTrue);

      final appliedV2 = Completer<void>();
      catalogImageFromKeyDebugOnResolveApplied = (key, version) {
        if (key == imageKey && version == 'v2' && !appliedV2.isCompleted) {
          appliedV2.complete();
        }
      };
      pending.complete('https://example.test/catalog/figures/$imageKey.webp?v=2');
      await _pumpUntil(tester, appliedV2);

      final shown = _resolved(tester);
      expect(shown.imageVersion, 'v2');
      expect(shown.imageRef, isNot(oldRef));
      expect(File(shown.imageRef).existsSync(), isTrue);

      // Failed refresh keeps previous art.
      CatalogImageResolver.getDownloadUrlOverride = (_) async {
        throw TimeoutException('refresh failed');
      };
      final kept = Completer<void>();
      catalogImageFromKeyDebugOnResolveApplied = (key, version) {
        if (key == imageKey && version == 'v2' && !kept.isCompleted) {
          kept.complete();
        }
      };
      CatalogBundleCache.prime(
        CatalogSeedBundle(
          brands: const [],
          ips: const [],
          series: const [],
          figures: [_figure(imageKey, 'v3')],
        ),
      );
      CatalogBundleCache.triggerBundleReplacedForTest();
      await tester.pump();
      await _pumpUntil(tester, kept);

      final afterFail = _resolved(tester);
      expect(afterFail.imageRef, shown.imageRef);
      expect(afterFail.imageVersion, 'v2');
      expect(File(afterFail.imageRef).existsSync(), isTrue);

      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  test(
    'new version persist writes new file before deleting the old version file',
    () async {
      const imageKey = 'keep_displayed';
      final pathV1 = await CatalogImageDiskCache.persistBytes(
        kind: CatalogImageKind.figure,
        imageKey: imageKey,
        extension: '.png',
        bytes: _pngBytes,
        imageVersion: 'v1',
      );
      expect(pathV1, isNotNull);
      expect(File(pathV1!).existsSync(), isTrue);

      final pathV2 = await CatalogImageDiskCache.persistBytes(
        kind: CatalogImageKind.figure,
        imageKey: imageKey,
        extension: '.png',
        bytes: List<int>.from(_pngBytes)..add(1),
        imageVersion: 'v2',
      );
      expect(pathV2, isNotNull);
      expect(File(pathV2!).existsSync(), isTrue);
      expect(File(pathV1).existsSync(), isFalse);
    },
  );

  test(
    'deleted local session path re-fetches Storage once and returns a live file',
    () async {
      const imageKey = 'missing_local';
      CatalogImageResolver.getDownloadUrlOverride = (path) async {
        if (path.endsWith('.webp')) {
          return 'https://example.test/$path';
        }
        return null;
      };

      final first = await CatalogImageResolver.resolveFigureStorageRef(
        imageKey,
      );
      expect(first, isNotNull);
      expect(File(first!).existsSync(), isTrue);

      await File(first).delete();
      CatalogImageResolver.storageExtensionProbeCount = 0;
      final second = await CatalogImageResolver.resolveFigureStorageRef(
        imageKey,
      );
      expect(second, isNotNull);
      expect(File(second!).existsSync(), isTrue);
      expect(CatalogImageResolver.storageExtensionProbeCount, greaterThan(0));

      // Second resolve with file present must not probe Storage again.
      CatalogImageResolver.storageExtensionProbeCount = 0;
      final third = await CatalogImageResolver.resolveFigureStorageRef(
        imageKey,
      );
      expect(third, second);
      expect(CatalogImageResolver.storageExtensionProbeCount, 0);
    },
  );

  testWidgets(
    'PathNotFound recovery re-resolves once and does not loop',
    (tester) async {
      const imageKey = 'path_missing_once';
      var resolveStarts = 0;
      final secondStart = Completer<void>();
      catalogImageFromKeyDebugOnResolveStart = (key, _) {
        if (key != imageKey) return;
        resolveStarts++;
        if (resolveStarts == 2 && !secondStart.isCompleted) {
          secondStart.complete();
        }
      };

      CatalogImageResolver.getDownloadUrlOverride = (path) async {
        if (path.endsWith('.webp')) {
          return 'https://example.test/$path';
        }
        return null;
      };

      void deleteCachedFiles() {
        final dir = Directory('${tempRoot.path}/figures');
        if (!dir.existsSync()) return;
        for (final entity in dir.listSync()) {
          if (entity is! File) continue;
          if (entity.uri.pathSegments.last.startsWith(imageKey)) {
            entity.deleteSync();
          }
        }
      }

      catalogImageFromKeyDebugOnResolveApplied = (key, _) {
        if (key == imageKey) deleteCachedFiles();
      };

      CatalogBundleCache.prime(
        CatalogSeedBundle(
          brands: const [],
          ips: const [],
          series: const [],
          figures: [_figure(imageKey, 'v1')],
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            relationshipHintForCatalogSeriesProvider.overrideWith(
              (ref, _) => null,
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 120,
                height: 120,
                child: CatalogImageFromKey(
                  imageKey: imageKey,
                  name: 'Fig',
                  seedKey: imageKey,
                  displayMode: CatalogImageDisplayMode.figureThumb,
                ),
              ),
            ),
          ),
        ),
      );

      await _pumpUntil(tester, secondStart);
      expect(resolveStarts, 2);

      for (var i = 0; i < 15; i++) {
        await tester.runAsync(() => Future<void>.delayed(Duration.zero));
        await tester.pump();
      }
      expect(resolveStarts, 2);

      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
