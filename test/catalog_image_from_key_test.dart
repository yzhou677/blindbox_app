import 'package:blindbox_app/features/catalog/application/catalog_bundle_cache.dart';
import 'package:blindbox_app/features/catalog/catalog_bundle.dart';
import 'package:blindbox_app/features/catalog/catalog_image_resolver.dart';
import 'package:blindbox_app/features/catalog/models/catalog_figure.dart';
import 'package:blindbox_app/features/catalog/presentation/catalog_image_display.dart';
import 'package:blindbox_app/features/collectible_relationship/application/collectible_relationship_providers.dart';
import 'package:blindbox_app/features/collection/widgets/collectible_figure_placeholder.dart';
import 'package:blindbox_app/shared/widgets/catalog_image_from_key.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CatalogImageResolveCoordinator', () {
    test('ignores stale async generations', () {
      final coordinator = CatalogImageResolveCoordinator();

      final first = coordinator.begin();

      final second = coordinator.begin();

      expect(coordinator.shouldApply(first), isFalse);

      expect(coordinator.shouldApply(second), isTrue);
    });
  });

  group('catalogImageResolveFrameWaits', () {
    test('batch 0 waits one frame', () {
      expect(catalogImageResolveFrameWaits(0), 1);
    });

    test('batch 1 waits two frames', () {
      expect(catalogImageResolveFrameWaits(1), 2);
    });

    test('batch 2 waits three frames', () {
      expect(catalogImageResolveFrameWaits(2), 3);
    });
  });

  group('scheduleCatalogImageResolveAfterFrames', () {
    testWidgets('invokes onReady after one frame for batch 0', (tester) async {
      var readyCount = 0;
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: SizedBox())),
      );

      scheduleCatalogImageResolveAfterFrames(
        staggerBatch: 0,
        isMounted: () => true,
        onReady: () => readyCount++,
      );

      expect(readyCount, 0);
      await tester.pump();
      expect(readyCount, 1);
    });
  });

  group('catalogImageWidgetKey', () {
    test('includes identity and imageKey for list stability', () {
      final key = catalogImageWidgetKey(
        displayMode: CatalogImageDisplayMode.seriesCoverThumb,
        imageKey: 'skullpanda_series_a',
        identity: 'skullpanda_series_a',
      );
      expect(key, isA<ValueKey<String>>());
      expect((key as ValueKey<String>).value, contains('skullpanda_series_a'));
    });
  });

  group('CatalogImageFromKey imageVersion refresh', () {
    CatalogFigure figureWithVersion(String imageVersion) {
      return CatalogFigure(
        id: 'dimoo_mood_fig',
        seriesId: 'dimoo_mood',
        brandId: 'pop_mart',
        ipId: 'dimoo',
        displayName: 'Mood',
        isSecret: false,
        sortOrder: 1,
        imageKey: 'dimoo_mood_fig',
        imageVersion: imageVersion,
      );
    }

    setUp(() {
      CatalogBundleCache.resetForTest();
      CatalogImageResolver.storageFallbackOverride = false;
      catalogImageFromKeyDebugOnResolveStart = null;
    });

    tearDown(() {
      catalogImageFromKeyDebugOnResolveStart = null;
      CatalogBundleCache.resetForTest();
      CatalogImageResolver.storageFallbackOverride = null;
    });

    testWidgets(
      're-resolves when catalog bundle imageVersion changes without remount',
      (tester) async {
        final resolveVersions = <String?>[];
        catalogImageFromKeyDebugOnResolveStart = (key, version) {
          if (key == 'dimoo_mood_fig') resolveVersions.add(version);
        };

        CatalogBundleCache.prime(
          CatalogSeedBundle(
            brands: const [],
            ips: const [],
            series: const [],
            figures: [figureWithVersion('version-one')],
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
                    imageKey: 'dimoo_mood_fig',
                    name: 'Mood',
                    seedKey: 'dimoo_mood_fig',
                    displayMode: CatalogImageDisplayMode.figureThumb,
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.pump();
        expect(resolveVersions, ['version-one']);
        expect(find.byType(CollectibleFigurePlaceholder), findsOneWidget);

        CatalogBundleCache.prime(
          CatalogSeedBundle(
            brands: const [],
            ips: const [],
            series: const [],
            figures: [figureWithVersion('version-two')],
          ),
        );
        CatalogBundleCache.triggerBundleReplacedForTest();
        await tester.pump();

        expect(resolveVersions, ['version-one', 'version-two']);
      },
    );

    testWidgets(
      'does not re-resolve when bundle imageVersion is unchanged',
      (tester) async {
        final resolveVersions = <String?>[];
        catalogImageFromKeyDebugOnResolveStart = (key, version) {
          if (key == 'dimoo_mood_fig') resolveVersions.add(version);
        };

        CatalogBundleCache.prime(
          CatalogSeedBundle(
            brands: const [],
            ips: const [],
            series: const [],
            figures: [figureWithVersion('version-one')],
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
                    imageKey: 'dimoo_mood_fig',
                    name: 'Mood',
                    seedKey: 'dimoo_mood_fig',
                    displayMode: CatalogImageDisplayMode.figureThumb,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        expect(resolveVersions, ['version-one']);

        CatalogBundleCache.triggerBundleReplacedForTest();
        await tester.pump();
        expect(resolveVersions, ['version-one']);
      },
    );
  });
}
