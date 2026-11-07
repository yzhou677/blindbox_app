import 'dart:convert';
import 'dart:io';

import 'package:blindbox_app/features/catalog/application/catalog_bundle_cache.dart';
import 'package:blindbox_app/features/catalog/catalog_bundle.dart';
import 'package:blindbox_app/features/catalog/catalog_image_resolver.dart';
import 'package:blindbox_app/features/catalog/data/catalog_image_disk_cache.dart';
import 'package:blindbox_app/features/catalog/data/catalog_image_version.dart';
import 'package:blindbox_app/features/catalog/models/catalog_figure.dart';
import 'package:blindbox_app/features/catalog/presentation/catalog_image_display.dart';
import 'package:blindbox_app/features/collectible_relationship/application/collectible_relationship_providers.dart';
import 'package:blindbox_app/features/collection/widgets/collectible_figure_placeholder.dart';
import 'package:blindbox_app/shared/widgets/catalog_image_from_key.dart';
import 'package:blindbox_app/shared/widgets/catalog_resolved_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Minimal 1×1 PNG.
final _pngBytes = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
);

const _md5V1 = 'AAAAAAAAAAAAAAAAAAAAAA==';

CatalogFigure _figure({
  required String imageKey,
  String? imageVersion,
}) {
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempRoot;

  setUp(() async {
    tempRoot = await Directory.systemTemp.createTemp(
      'catalog_img_dangling_',
    );
    CatalogImageDiskCache.testRootOverride = tempRoot;
    CatalogImageDiskCache.httpClientOverride = MockClient((request) async {
      return http.Response.bytes(_pngBytes, 200);
    });
    CatalogImageResolver.resetSessionCachesForTest();
    CatalogImageResolver.storageFallbackOverride = true;
    CatalogImageResolver.firebaseStorageReadyOverride = true;
    CatalogImageResolver.isOnlineOverride = () async => true;
    CatalogImageResolver.delayOverride = (_) async {};
    CatalogBundleCache.resetForTest();
    catalogImageFromKeyDebugOnResolveStart = null;
    catalogImageFromKeyDebugOnResolveApplied = null;
    catalogImageFromKeyDebugOnResolveDiscarded = null;
  });

  tearDown(() async {
    catalogImageFromKeyDebugOnResolveStart = null;
    catalogImageFromKeyDebugOnResolveApplied = null;
    catalogImageFromKeyDebugOnResolveDiscarded = null;
    CatalogBundleCache.resetForTest();
    CatalogImageResolver.resetSessionCachesForTest();
    CatalogImageResolver.storageFallbackOverride = null;
    CatalogImageDiskCache.resetForTest();
    if (await tempRoot.exists()) {
      try {
        await tempRoot.delete(recursive: true);
      } on FileSystemException {
        // Windows may still hold open cache files from Image widgets.
      }
    }
  });

  test(
    'session path whose file was deleted re-resolves Storage and returns a live file',
    () async {
      const imageKey = 'dangling_session';
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
      expect(File(first).existsSync(), isFalse);

      CatalogImageResolver.storageExtensionProbeCount = 0;
      final second = await CatalogImageResolver.resolveFigureStorageRef(
        imageKey,
      );
      expect(second, isNotNull);
      expect(File(second!).existsSync(), isTrue);
      expect(CatalogImageResolver.storageExtensionProbeCount, greaterThan(0));
    },
  );

  test(
    'unversioned then versioned persist leaves a display path that still exists',
    () async {
      const imageKey = 'version_flip';
      final unversioned = await CatalogImageDiskCache.persistBytes(
        kind: CatalogImageKind.figure,
        imageKey: imageKey,
        extension: '.png',
        bytes: _pngBytes,
      );
      expect(unversioned, isNotNull);
      expect(File(unversioned!).existsSync(), isTrue);

      // Prime session with the unversioned path (as a prior resolve would).
      final unversionedKey = CatalogImageVersion.diskEntryKey(
        kind: CatalogImageKind.figure,
        imageKey: imageKey,
      );
      CatalogImageResolver.seedSessionDisplayRefForTest(
        unversionedKey,
        unversioned,
      );
      expect(
        CatalogImageResolver.sessionDisplayRefForTest(unversionedKey),
        unversioned,
      );

      final versioned = await CatalogImageDiskCache.persistBytes(
        kind: CatalogImageKind.figure,
        imageKey: imageKey,
        extension: '.png',
        bytes: List<int>.from(_pngBytes)..add(1),
        imageVersion: _md5V1,
      );
      expect(versioned, isNotNull);
      expect(File(versioned!).existsSync(), isTrue);
      expect(File(unversioned).existsSync(), isFalse);

      // Purged unversioned session entry must be gone.
      expect(
        CatalogImageResolver.sessionDisplayRefForTest(unversionedKey),
        isNull,
      );

      CatalogImageResolver.getDownloadUrlOverride = (path) async {
        fail('versioned disk hit must not probe Storage: $path');
      };
      final shown = await CatalogImageResolver.resolveFigureStorageRef(
        imageKey,
        imageVersion: _md5V1,
      );
      expect(shown, isNotNull);
      expect(File(shown!).existsSync(), isTrue);
      expect(shown, versioned);
    },
  );

  testWidgets(
    'PathNotFound notifies onLocalPathMissing only once per mount',
    (tester) async {
      final missing = File('${tempRoot.path}/missing_once.png');
      expect(missing.existsSync(), isFalse);

      var calls = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 80,
              height: 80,
              child: CatalogResolvedImage(
                imageRef: missing.path,
                spec: CatalogImageDisplaySpec.forMode(
                  CatalogImageDisplayMode.figureThumb,
                  imageRef: missing.path,
                ),
                name: 'Fig',
                seedKey: 'missing_once',
                onLocalPathMissing: () => calls++,
              ),
            ),
          ),
        ),
      );
      for (var i = 0; i < 40 && calls < 1; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump();
      }
      expect(calls, 1);
      expect(find.byType(CollectibleFigurePlaceholder), findsOneWidget);

      for (var i = 0; i < 10; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump();
      }
      expect(calls, 1);
    },
  );

  testWidgets(
    'FromKey PathNotFound recovery re-resolves once and does not loop',
    (tester) async {
      const imageKey = 'path_not_found_once';
      var resolveStarts = 0;
      catalogImageFromKeyDebugOnResolveStart = (key, _) {
        if (key == imageKey) resolveStarts++;
      };

      CatalogImageResolver.getDownloadUrlOverride = (path) async {
        if (path.endsWith('.webp')) {
          return 'https://example.test/$path';
        }
        return null;
      };

      // Delete the just-persisted file synchronously in Applied — before the
      // next frame paints Image.file — so PathNotFound fires and triggers
      // one recovery. Keep deleting so a runaway loop would keep resolving.
      void deleteCachedFigureFiles() {
        final dir = Directory('${tempRoot.path}/figures');
        if (!dir.existsSync()) return;
        for (final entity in dir.listSync()) {
          if (entity is! File) continue;
          final name = entity.uri.pathSegments.last;
          if (name.startsWith(imageKey)) {
            entity.deleteSync();
          }
        }
      }

      catalogImageFromKeyDebugOnResolveApplied = (key, _) {
        if (key != imageKey) return;
        deleteCachedFigureFiles();
      };

      CatalogBundleCache.prime(
        CatalogSeedBundle(
          brands: const [],
          ips: const [],
          series: const [],
          figures: [_figure(imageKey: imageKey)],
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

      // Initial resolve + one PathNotFound recovery.
      for (var i = 0; i < 80 && resolveStarts < 2; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump();
      }
      expect(resolveStarts, 2);

      // Runaway would keep climbing — must stay capped at one recovery.
      for (var i = 0; i < 30; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump();
      }
      expect(resolveStarts, 2);

      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
