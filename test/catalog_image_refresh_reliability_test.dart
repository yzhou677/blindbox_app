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
import 'package:blindbox_app/features/collection/widgets/collectible_figure_placeholder.dart';
import 'package:blindbox_app/shared/widgets/app_image_shimmer.dart';
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

CatalogFigure _figure({
  required String imageKey,
  required String imageVersion,
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
      'catalog_img_refresh_reliability_',
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
  });

  tearDown(() async {
    catalogImageFromKeyDebugOnResolveStart = null;
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

  group('Storage retry + gate isolation', () {
    test('first timeout then success on retry shows a resolved ref', () async {
      var attempts = 0;
      CatalogImageResolver.getDownloadUrlOverride = (path) async {
        if (!path.endsWith('.webp')) return null;
        attempts++;
        if (attempts == 1) {
          throw TimeoutException('first attempt');
        }
        return 'https://example.test/$path';
      };

      final ref = await CatalogImageResolver.resolveFigureStorageRef(
        'retry_then_ok',
        imageVersion: 'v2',
      );

      expect(ref, isNotNull);
      expect(attempts, 2);
      expect(CatalogImageResolver.storageTransportUnavailable, isFalse);
      expect(CatalogImageResolver.consecutiveTransportFailureCount, 0);
    });

    test('retry budget is capped; all failures yield null', () async {
      CatalogImageResolver.getDownloadUrlOverride = (_) async {
        throw TimeoutException('always');
      };

      final ref = await CatalogImageResolver.resolveFigureStorageRef(
        'always_timeout',
      );

      expect(ref, isNull);
      expect(
        CatalogImageResolver.storageExtensionProbeCount,
        CatalogImageResolver.assetExtensions.length *
            (1 + CatalogImageResolver.maxStorageFetchRetries),
      );
      expect(CatalogImageResolver.storageTransportUnavailable, isFalse);
    });

    test('one key timeout does not skip a different key', () async {
      CatalogImageResolver.getDownloadUrlOverride = (path) async {
        if (path.contains('bad_key')) {
          throw TimeoutException('bad');
        }
        if (path.endsWith('.webp')) {
          return 'https://example.test/$path';
        }
        return null;
      };

      expect(
        await CatalogImageResolver.resolveFigureStorageRef('bad_key'),
        isNull,
      );
      expect(CatalogImageResolver.storageTransportUnavailable, isFalse);

      CatalogImageResolver.storageExtensionProbeCount = 0;
      final ok = await CatalogImageResolver.resolveFigureStorageRef('good_key');
      expect(ok, isNotNull);
      expect(CatalogImageResolver.storageExtensionProbeCount, 1);
    });

    test(
      'consecutive distinct key failures trip the gate; TTL clears it',
      () async {
        var clock = DateTime.utc(2026, 1, 1, 12);
        CatalogImageResolver.nowOverride = () => clock;
        CatalogImageResolver.getDownloadUrlOverride = (_) async {
          throw TimeoutException('down');
        };

        for (var i = 0;
            i < CatalogImageResolver.consecutiveTransportFailuresToTripGate;
            i++) {
          expect(
            await CatalogImageResolver.resolveFigureStorageRef('fail_$i'),
            isNull,
          );
        }
        expect(CatalogImageResolver.storageTransportUnavailable, isTrue);

        CatalogImageResolver.storageExtensionProbeCount = 0;
        CatalogImageResolver.getDownloadUrlOverride = (_) async {
          fail('gated keys must not probe before TTL');
        };
        expect(
          await CatalogImageResolver.resolveFigureStorageRef('blocked'),
          isNull,
        );
        expect(CatalogImageResolver.storageExtensionProbeCount, 0);

        clock = clock.add(
          CatalogImageResolver.transportGateTtl + const Duration(seconds: 1),
        );
        CatalogImageResolver.getDownloadUrlOverride = (path) async {
          if (path.endsWith('.webp')) return 'https://example.test/$path';
          return null;
        };
        final recovered = await CatalogImageResolver.resolveFigureStorageRef(
          'after_ttl',
        );
        expect(recovered, isNotNull);
        expect(CatalogImageResolver.storageTransportUnavailable, isFalse);
      },
    );
  });

  group('CatalogImageFromKey stale-while-revalidate', () {
    /// Disk/Storage futures run outside FakeAsync; shimmer also animates.
    /// Drain real IO then pump until FromKey leaves the loading shimmer.
    Future<void> waitForFromKeyIdle(WidgetTester tester) async {
      for (var i = 0; i < 80; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump();
        if (find.byType(AppImageShimmer).evaluate().isEmpty) {
          return;
        }
      }
      fail('CatalogImageFromKey stayed on shimmer');
    }

    Future<void> pumpFromKey(WidgetTester tester, {Key? key}) async {
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
                  key: key,
                  imageKey: 'swr_fig',
                  name: 'Fig',
                  seedKey: 'swr_fig',
                  displayMode: CatalogImageDisplayMode.figureThumb,
                ),
              ),
            ),
          ),
        ),
      );
      await waitForFromKeyIdle(tester);
    }

    testWidgets(
      'bundle replace keeps old art until the new version resolves',
      (tester) async {
        final resolveVersions = <String?>[];
        catalogImageFromKeyDebugOnResolveStart = (key, version) {
          if (key == 'swr_fig') resolveVersions.add(version);
        };

        CatalogImageResolver.getDownloadUrlOverride = (path) async {
          if (path.endsWith('.webp')) {
            return 'https://example.test/$path?v=old';
          }
          return null;
        };

        CatalogBundleCache.prime(
          CatalogSeedBundle(
            brands: const [],
            ips: const [],
            series: const [],
            figures: [_figure(imageKey: 'swr_fig', imageVersion: 'v1')],
          ),
        );

        await pumpFromKey(tester);
        expect(resolveVersions, ['v1']);
        expect(find.byType(CatalogResolvedImage), findsOneWidget);
        expect(find.byType(CollectibleFigurePlaceholder), findsNothing);
        expect(find.byType(AppImageShimmer), findsNothing);

        final pending = Completer<String?>();
        CatalogImageResolver.getDownloadUrlOverride = (path) async {
          if (!path.endsWith('.webp')) return null;
          return pending.future;
        };

        CatalogBundleCache.prime(
          CatalogSeedBundle(
            brands: const [],
            ips: const [],
            series: const [],
            figures: [_figure(imageKey: 'swr_fig', imageVersion: 'v2')],
          ),
        );
        CatalogBundleCache.triggerBundleReplacedForTest();
        // One frame to start the refresh; do not settle while Completer is open.
        await tester.pump();

        // Still showing previous art — no shimmer / placeholder flash.
        expect(resolveVersions, ['v1', 'v2']);
        expect(find.byType(CatalogResolvedImage), findsOneWidget);
        expect(find.byType(CollectibleFigurePlaceholder), findsNothing);
        expect(find.byType(AppImageShimmer), findsNothing);

        pending.complete(
          'https://example.test/catalog/figures/swr_fig.webp?v=2',
        );
        await waitForFromKeyIdle(tester);

        expect(find.byType(CatalogResolvedImage), findsOneWidget);
        expect(find.byType(CollectibleFigurePlaceholder), findsNothing);

        await tester.pumpWidget(const SizedBox.shrink());
      },
    );

    testWidgets(
      'failed refresh after bundle replace keeps the previous image',
      (tester) async {
        CatalogImageResolver.getDownloadUrlOverride = (path) async {
          if (path.endsWith('.webp')) {
            return 'https://example.test/$path';
          }
          return null;
        };

        CatalogBundleCache.prime(
          CatalogSeedBundle(
            brands: const [],
            ips: const [],
            series: const [],
            figures: [_figure(imageKey: 'swr_fig', imageVersion: 'v1')],
          ),
        );
        await pumpFromKey(tester);
        expect(find.byType(CatalogResolvedImage), findsOneWidget);

        CatalogImageResolver.getDownloadUrlOverride = (_) async {
          throw TimeoutException('refresh failed');
        };

        CatalogBundleCache.prime(
          CatalogSeedBundle(
            brands: const [],
            ips: const [],
            series: const [],
            figures: [_figure(imageKey: 'swr_fig', imageVersion: 'v2')],
          ),
        );
        CatalogBundleCache.triggerBundleReplacedForTest();
        await waitForFromKeyIdle(tester);

        expect(find.byType(CatalogResolvedImage), findsOneWidget);
        expect(find.byType(CollectibleFigurePlaceholder), findsNothing);

        await tester.pumpWidget(const SizedBox.shrink());
      },
    );

    testWidgets(
      'first timeout then retry success updates the displayed image',
      (tester) async {
        var webpAttempts = 0;
        CatalogImageResolver.getDownloadUrlOverride = (path) async {
          if (!path.endsWith('.webp')) return null;
          webpAttempts++;
          if (webpAttempts == 1) {
            throw TimeoutException('transient');
          }
          return 'https://example.test/$path';
        };

        CatalogBundleCache.prime(
          CatalogSeedBundle(
            brands: const [],
            ips: const [],
            series: const [],
            figures: [_figure(imageKey: 'swr_fig', imageVersion: 'v1')],
          ),
        );
        await pumpFromKey(tester);

        expect(webpAttempts, 2);
        expect(find.byType(CatalogResolvedImage), findsOneWidget);
        expect(find.byType(CollectibleFigurePlaceholder), findsNothing);

        await tester.pumpWidget(const SizedBox.shrink());
      },
    );

    testWidgets(
      'exhausted retries with no prior art show placeholder',
      (tester) async {
        CatalogImageResolver.getDownloadUrlOverride = (_) async {
          throw TimeoutException('hard fail');
        };

        CatalogBundleCache.prime(
          CatalogSeedBundle(
            brands: const [],
            ips: const [],
            series: const [],
            figures: [_figure(imageKey: 'swr_fig', imageVersion: 'v1')],
          ),
        );
        await pumpFromKey(tester);

        expect(find.byType(CollectibleFigurePlaceholder), findsOneWidget);
        expect(find.byType(CatalogResolvedImage), findsNothing);

        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  });
}
