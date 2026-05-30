import 'dart:io';

import 'package:blindbox_app/features/catalog/catalog_image_resolver.dart';
import 'package:blindbox_app/features/catalog/data/catalog_image_disk_cache.dart';
import 'package:blindbox_app/features/catalog/presentation/catalog_image_display.dart';
import 'package:blindbox_app/features/collectible_relationship/application/collectible_relationship_providers.dart';
import 'package:blindbox_app/shared/widgets/catalog_image_from_key.dart';
import 'package:blindbox_app/features/collection/widgets/collectible_figure_placeholder.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Bundled in repo under assets/catalog/figures/.
const _bundledFigureKey = 'the_monsters_exciting_macaron_soymilk';

/// Bundled in repo under assets/catalog/series/.
const _bundledSeriesKey = 'the_monsters_exciting_macaron';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempCacheRoot;

  setUp(() async {
    tempCacheRoot = await Directory.systemTemp.createTemp(
      'catalog_fallback_test_',
    );
    CatalogImageDiskCache.testRootOverride = tempCacheRoot;
  });

  tearDown(() async {
    CatalogImageResolver.resetSessionCachesForTest();
    CatalogImageResolver.storageFallbackOverride = null;
    CatalogImageDiskCache.resetForTest();
    if (await tempCacheRoot.exists()) {
      await tempCacheRoot.delete(recursive: true);
    }
  });

  group('resolver contract', () {
    test('storage fallback is on by default', () {
      CatalogImageResolver.storageFallbackOverride = null;
      expect(CatalogImageResolver.storageFallbackEnabled, isTrue);
    });

    test(
      '1) storageFallback=false + local asset exists → bundled path',
      () async {
        CatalogImageResolver.storageFallbackOverride = false;
        await CatalogImageResolver.ensureReady();

        final ref = await CatalogImageResolver.resolveFigureDisplayRef(
          _bundledFigureKey,
        );

        expect(ref, 'assets/catalog/figures/$_bundledFigureKey.png');
      },
    );

    test(
      '2) storageFallback=false + local asset missing → null',
      () async {
        CatalogImageResolver.storageFallbackOverride = false;
        await CatalogImageResolver.ensureReady();

        final ref = await CatalogImageResolver.resolveFigureDisplayRef(
          'catalog_key_with_no_bundled_or_storage_asset',
        );

        expect(ref, isNull);
      },
    );

    test(
      '3) storageFallback=true + local missing + no Firebase → null',
      () async {
        CatalogImageResolver.storageFallbackOverride = true;
        CatalogImageResolver.firebaseStorageReadyOverride = false;
        await CatalogImageResolver.ensureReady();

        final ref = await CatalogImageResolver.resolveFigureStorageRef(
          'catalog_key_with_no_bundled_or_storage_asset',
        );

        expect(ref, isNull);
      },
    );

    test(
      '4) storageFallback=true does not block bundled asset resolution',
      () async {
        CatalogImageResolver.storageFallbackOverride = true;
        await CatalogImageResolver.ensureReady();

        final ref = await CatalogImageResolver.resolveFigureDisplayRef(
          _bundledFigureKey,
        );

        expect(ref, 'assets/catalog/figures/$_bundledFigureKey.png');
      },
    );

    test('series bundled asset resolves with storage fallback off', () async {
      CatalogImageResolver.storageFallbackOverride = false;
      await CatalogImageResolver.ensureReady();

      final ref = await CatalogImageResolver.resolveSeriesDisplayRef(
        _bundledSeriesKey,
      );

      expect(ref, 'assets/catalog/series/$_bundledSeriesKey.png');
    });
  });

  group('CatalogImageFromKey widget', () {
    testWidgets('shows real bundled image when storage fallback is off', (
      tester,
    ) async {
      CatalogImageResolver.storageFallbackOverride = false;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            relationshipHintForCatalogSeriesProvider.overrideWith((ref, _) => null),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 120,
                height: 120,
                child: CatalogImageFromKey(
                  imageKey: _bundledFigureKey,
                  name: 'Soymilk',
                  seedKey: _bundledFigureKey,
                  displayMode: CatalogImageDisplayMode.figureThumb,
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(CollectibleFigurePlaceholder), findsNothing);
      expect(find.byType(Image), findsWidgets);
    });

    testWidgets('shows placeholder when bundled missing and storage off', (
      tester,
    ) async {
      CatalogImageResolver.storageFallbackOverride = false;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            relationshipHintForCatalogSeriesProvider.overrideWith((ref, _) => null),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 120,
                height: 120,
                child: CatalogImageFromKey(
                  imageKey: 'missing_catalog_asset_key_xyz',
                  name: 'Missing',
                  seedKey: 'missing',
                  displayMode: CatalogImageDisplayMode.figureThumb,
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(CollectibleFigurePlaceholder), findsOneWidget);
    });
  });
}
