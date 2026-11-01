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
      'storageFallback=false skips Storage and returns null',
      () async {
        CatalogImageResolver.storageFallbackOverride = false;

        final ref = await CatalogImageResolver.resolveFigureDisplayRef(
          'any_catalog_image_key',
        );

        expect(ref, isNull);
      },
    );

    test('storageFallback=false + missing key → null', () async {
      CatalogImageResolver.storageFallbackOverride = false;

      final ref = await CatalogImageResolver.resolveFigureDisplayRef(
        'catalog_key_with_no_disk_or_storage_asset',
      );

      expect(ref, isNull);
    });

    test(
      'storageFallback=true + no Firebase → null',
      () async {
        CatalogImageResolver.storageFallbackOverride = true;
        CatalogImageResolver.firebaseStorageReadyOverride = false;

        final ref = await CatalogImageResolver.resolveFigureStorageRef(
          'catalog_key_with_no_disk_or_storage_asset',
        );

        expect(ref, isNull);
      },
    );

    test('series resolve with storage fallback off returns null', () async {
      CatalogImageResolver.storageFallbackOverride = false;

      final ref = await CatalogImageResolver.resolveSeriesDisplayRef(
        'the_monsters_exciting_macaron',
      );

      expect(ref, isNull);
    });
  });

  group('CatalogImageFromKey widget', () {
    testWidgets('shows placeholder when storage fallback is off', (
      tester,
    ) async {
      CatalogImageResolver.storageFallbackOverride = false;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            relationshipHintForCatalogSeriesProvider.overrideWith(
              (ref, _) => null,
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 120,
                height: 120,
                child: CatalogImageFromKey(
                  imageKey: 'the_monsters_exciting_macaron_soymilk',
                  name: 'Soymilk',
                  seedKey: 'the_monsters_exciting_macaron_soymilk',
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

    testWidgets('shows placeholder when key missing and storage off', (
      tester,
    ) async {
      CatalogImageResolver.storageFallbackOverride = false;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            relationshipHintForCatalogSeriesProvider.overrideWith(
              (ref, _) => null,
            ),
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
