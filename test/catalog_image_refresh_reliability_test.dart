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
import 'package:blindbox_app/shared/widgets/catalog_image_from_key.dart';
import 'package:blindbox_app/shared/widgets/catalog_resolved_image.dart';
import 'package:firebase_core/firebase_core.dart';
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

CatalogResolvedImage _resolved(WidgetTester tester) {
  return tester.widget<CatalogResolvedImage>(
    find.byType(CatalogResolvedImage),
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

  group('Storage retry + gate isolation', () {
    test(
      'transport error then success on retry shows a resolved ref',
      () async {
        var attempts = 0;
        CatalogImageResolver.getDownloadUrlOverride = (path) async {
          if (!path.endsWith('.webp')) return null;
          attempts++;
          if (attempts == 1) {
            throw FirebaseException(
              plugin: 'firebase_storage',
              code: 'unavailable',
              message: 'transient',
            );
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
      },
    );

    test('webp timeout then png hit within same attempt', () async {
      CatalogImageResolver.getDownloadUrlOverride = (path) async {
        if (path.endsWith('.webp')) {
          throw TimeoutException('webp slow');
        }
        if (path.endsWith('.png')) {
          return 'https://example.test/$path';
        }
        return null;
      };

      final ref = await CatalogImageResolver.resolveFigureStorageRef(
        'webp_then_png',
      );
      expect(ref, isNotNull);
      expect(CatalogImageResolver.storageTransportUnavailable, isFalse);
    });

    test(
      'timed-out extensions are not re-probed on later attempts',
      () async {
        final probed = <String>[];
        CatalogImageResolver.getDownloadUrlOverride = (path) async {
          probed.add(path);
          throw TimeoutException('always');
        };

        final ref = await CatalogImageResolver.resolveFigureStorageRef(
          'no_reprobe_timeouts',
        );

        expect(ref, isNull);
        // One pass over all extensions; retries skip already-timed-out exts.
        expect(
          probed.length,
          CatalogImageResolver.assetExtensions.length,
        );
        expect(CatalogImageResolver.storageTransportUnavailable, isFalse);
      },
    );

    test('resolve budget stops further probes', () async {
      var clock = DateTime.utc(2026, 1, 1, 12);
      CatalogImageResolver.nowOverride = () => clock;
      CatalogImageResolver.storageResolveBudgetOverride = const Duration(
        seconds: 20,
      );
      CatalogImageResolver.getDownloadUrlOverride = (path) async {
        // Each probe "costs" 9s of wall clock for budget accounting.
        clock = clock.add(const Duration(seconds: 9));
        throw TimeoutException('slow');
      };

      final ref = await CatalogImageResolver.resolveFigureStorageRef(
        'budget_key',
      );

      expect(ref, isNull);
      // 20s budget / 9s per probe ⇒ at most 3 probes, not 5×3.
      expect(CatalogImageResolver.storageExtensionProbeCount, lessThanOrEqualTo(3));
      expect(CatalogImageResolver.storageExtensionProbeCount, greaterThanOrEqualTo(2));
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

    test('same key failing repeatedly does not trip the global gate', () async {
      CatalogImageResolver.getDownloadUrlOverride = (_) async {
        throw TimeoutException('same key');
      };

      for (var i = 0; i < 5; i++) {
        expect(
          await CatalogImageResolver.resolveFigureStorageRef('same_key'),
          isNull,
        );
      }
      expect(CatalogImageResolver.consecutiveTransportFailureCount, 1);
      expect(CatalogImageResolver.storageTransportUnavailable, isFalse);
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
        expect(
          CatalogImageResolver.consecutiveTransportFailureCount,
          CatalogImageResolver.consecutiveTransportFailuresToTripGate,
        );

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

    test('concurrency slot releases after a failed resolve', () async {
      CatalogImageResolver.maxConcurrentStorageFetchesOverride = 1;
      final firstEntered = Completer<void>();
      final secondWaiting = Completer<void>();
      final releaseFirst = Completer<void>();
      var secondStarted = false;

      CatalogImageResolver.getDownloadUrlOverride = (path) async {
        if (path.contains('first_slot')) {
          if (!firstEntered.isCompleted) firstEntered.complete();
          await releaseFirst.future;
          throw TimeoutException('first failed');
        }
        if (path.contains('second_slot') && path.endsWith('.webp')) {
          secondStarted = true;
          return 'https://example.test/$path';
        }
        return null;
      };

      final first = CatalogImageResolver.resolveFigureStorageRef('first_slot');
      await firstEntered.future;
      expect(CatalogImageResolver.activeStorageFetchCount, 1);

      final second = CatalogImageResolver.resolveFigureStorageRef('second_slot');
      // Second is blocked on the concurrency waiter — poll until queued.
      while (CatalogImageResolver.storageFetchWaiterCount == 0) {
        await Future<void>.delayed(Duration.zero);
        if (secondStarted) fail('second started before first released');
      }
      if (!secondWaiting.isCompleted) secondWaiting.complete();
      await secondWaiting.future;
      expect(secondStarted, isFalse);
      expect(CatalogImageResolver.activeStorageFetchCount, 1);

      releaseFirst.complete();
      expect(await first, isNull);
      expect(await second, isNotNull);
      expect(secondStarted, isTrue);
      expect(CatalogImageResolver.activeStorageFetchCount, 0);
    });

    test(
      'stuck persist download times out within budget and releases slot',
      () async {
        CatalogImageResolver.maxConcurrentStorageFetchesOverride = 1;
        CatalogImageResolver.storageResolveBudgetOverride = const Duration(
          milliseconds: 80,
        );
        CatalogImageResolver.maxStorageFetchRetriesOverride = 0;

        final downloadStarted = Completer<void>();
        CatalogImageDiskCache.httpClientOverride = MockClient((request) async {
          if (!downloadStarted.isCompleted) downloadStarted.complete();
          // Hang forever — budget must cut this off.
          await Completer<void>().future;
          return http.Response.bytes(_pngBytes, 200);
        });
        CatalogImageResolver.getDownloadUrlOverride = (path) async {
          if (path.endsWith('.webp')) {
            return 'https://example.test/$path';
          }
          return null;
        };

        final resolve = CatalogImageResolver.resolveFigureStorageRef(
          'stuck_persist',
        );
        await downloadStarted.future;
        expect(CatalogImageResolver.activeStorageFetchCount, 1);

        expect(await resolve, isNull);
        expect(CatalogImageResolver.activeStorageFetchCount, 0);
      },
    );
  });

  group('CatalogImageFromKey stale-while-revalidate', () {
    Completer<String?> appliedFor(String version) {
      final done = Completer<String?>();
      catalogImageFromKeyDebugOnResolveApplied = (key, v) {
        if (key == 'swr_fig' && v == version && !done.isCompleted) {
          done.complete(v);
        }
      };
      return done;
    }

    Completer<void> discardedSignal() {
      final done = Completer<void>();
      catalogImageFromKeyDebugOnResolveDiscarded = (key, _) {
        if (key == 'swr_fig' && !done.isCompleted) done.complete();
      };
      return done;
    }

    Future<void> pumpUntil(WidgetTester tester, Completer completer) async {
      while (!completer.isCompleted) {
        await tester.runAsync(() => Future<void>.delayed(Duration.zero));
        await tester.pump();
      }
      await tester.pump();
    }

    Future<void> pumpFromKey(WidgetTester tester) async {
      final applied = appliedFor('v1');
      CatalogBundleCache.prime(
        CatalogSeedBundle(
          brands: const [],
          ips: const [],
          series: const [],
          figures: [_figure(imageKey: 'swr_fig', imageVersion: 'v1')],
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
      await pumpUntil(tester, applied);
    }

    testWidgets(
      'bundle replace keeps old art and version until new resolve succeeds',
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

        await pumpFromKey(tester);
        expect(resolveVersions, ['v1']);
        final first = _resolved(tester);
        final firstRef = first.imageRef;
        expect(first.imageVersion, 'v1');

        final v2Entered = Completer<void>();
        final pending = Completer<String?>();
        CatalogImageResolver.getDownloadUrlOverride = (path) async {
          if (!path.endsWith('.webp')) return null;
          if (!v2Entered.isCompleted) v2Entered.complete();
          return pending.future;
        };

        final appliedV2 = appliedFor('v2');
        CatalogBundleCache.prime(
          CatalogSeedBundle(
            brands: const [],
            ips: const [],
            series: const [],
            figures: [_figure(imageKey: 'swr_fig', imageVersion: 'v2')],
          ),
        );
        CatalogBundleCache.triggerBundleReplacedForTest();
        await tester.pump();
        await pumpUntil(tester, v2Entered);

        expect(resolveVersions, ['v1', 'v2']);
        final mid = _resolved(tester);
        expect(mid.imageRef, firstRef);
        expect(mid.imageVersion, 'v1');

        pending.complete(
          'https://example.test/catalog/figures/swr_fig.webp?v=2',
        );
        await pumpUntil(tester, appliedV2);

        final after = _resolved(tester);
        expect(after.imageVersion, 'v2');
        expect(after.imageRef, isNot(firstRef));

        await tester.pumpWidget(const SizedBox.shrink());
      },
    );

    testWidgets(
      'failed refresh keeps previous imageRef and displayed version',
      (tester) async {
        CatalogImageResolver.getDownloadUrlOverride = (path) async {
          if (path.endsWith('.webp')) {
            return 'https://example.test/$path';
          }
          return null;
        };

        await pumpFromKey(tester);
        final before = _resolved(tester);
        expect(before.imageVersion, 'v1');

        final failDone = Completer<void>();
        var failProbes = 0;
        CatalogImageResolver.getDownloadUrlOverride = (_) async {
          failProbes++;
          if (failProbes >= CatalogImageResolver.assetExtensions.length &&
              !failDone.isCompleted) {
            // Resolve pipeline finishes after the last probe returns.
            scheduleMicrotask(() {
              if (!failDone.isCompleted) failDone.complete();
            });
          }
          throw TimeoutException('refresh failed');
        };

        final appliedKeep = Completer<String?>();
        catalogImageFromKeyDebugOnResolveApplied = (key, v) {
          // Failed refresh still "applies" with displayed version staying v1.
          if (key == 'swr_fig' && v == 'v1' && !appliedKeep.isCompleted) {
            appliedKeep.complete(v);
          }
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
        await tester.pump();
        await pumpUntil(tester, failDone);
        await pumpUntil(tester, appliedKeep);

        final after = _resolved(tester);
        expect(after.imageRef, before.imageRef);
        expect(after.imageVersion, 'v1');
        expect(find.byType(CollectibleFigurePlaceholder), findsNothing);

        await tester.pumpWidget(const SizedBox.shrink());
      },
    );

    testWidgets(
      'out-of-order resolves keep the newer generation',
      (tester) async {
        final v1Gate = Completer<String?>();
        final v2Gate = Completer<String?>();
        final v1Entered = Completer<void>();
        final v2Entered = Completer<void>();
        var stage = 'v1';

        CatalogImageResolver.getDownloadUrlOverride = (path) async {
          if (!path.endsWith('.webp')) return null;
          if (stage == 'v1') {
            if (!v1Entered.isCompleted) v1Entered.complete();
            return v1Gate.future;
          }
          if (!v2Entered.isCompleted) v2Entered.complete();
          return v2Gate.future;
        };

        CatalogBundleCache.prime(
          CatalogSeedBundle(
            brands: const [],
            ips: const [],
            series: const [],
            figures: [_figure(imageKey: 'swr_fig', imageVersion: 'v1')],
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
        await tester.pump();
        await pumpUntil(tester, v1Entered);

        stage = 'v2';
        final appliedV2 = appliedFor('v2');
        final discardedV1 = discardedSignal();
        CatalogBundleCache.prime(
          CatalogSeedBundle(
            brands: const [],
            ips: const [],
            series: const [],
            figures: [_figure(imageKey: 'swr_fig', imageVersion: 'v2')],
          ),
        );
        CatalogBundleCache.triggerBundleReplacedForTest();
        await tester.pump();
        await pumpUntil(tester, v2Entered);

        v2Gate.complete('https://example.test/catalog/figures/swr_fig.webp?v2');
        await pumpUntil(tester, appliedV2);
        final newer = _resolved(tester);
        expect(newer.imageVersion, 'v2');
        expect(newer.imageRef, contains('v2'));

        v1Gate.complete('https://example.test/catalog/figures/swr_fig.webp?v1');
        await pumpUntil(tester, discardedV1);
        await tester.pump();

        final still = _resolved(tester);
        expect(still.imageVersion, 'v2');
        expect(still.imageRef, newer.imageRef);

        await tester.pumpWidget(const SizedBox.shrink());
      },
    );

    testWidgets(
      'bundle rollback to v1 while v2 loads keeps v1 after v2 completes',
      (tester) async {
        CatalogImageResolver.getDownloadUrlOverride = (path) async {
          if (path.endsWith('.webp')) {
            return 'https://example.test/$path?v=1';
          }
          return null;
        };
        await pumpFromKey(tester);
        final v1 = _resolved(tester);
        expect(v1.imageVersion, 'v1');

        final v2Entered = Completer<void>();
        final v2Gate = Completer<String?>();
        CatalogImageResolver.getDownloadUrlOverride = (path) async {
          if (!path.endsWith('.webp')) return null;
          if (!v2Entered.isCompleted) v2Entered.complete();
          return v2Gate.future;
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
        await tester.pump();
        await pumpUntil(tester, v2Entered);
        expect(_resolved(tester).imageVersion, 'v1');

        final discardedOnRollback = discardedSignal();
        CatalogBundleCache.prime(
          CatalogSeedBundle(
            brands: const [],
            ips: const [],
            series: const [],
            figures: [_figure(imageKey: 'swr_fig', imageVersion: 'v1')],
          ),
        );
        CatalogBundleCache.triggerBundleReplacedForTest();
        await tester.pump();
        await pumpUntil(tester, discardedOnRollback);
        expect(_resolved(tester).imageVersion, 'v1');
        expect(_resolved(tester).imageRef, v1.imageRef);

        final discardedLateV2 = discardedSignal();
        v2Gate.complete('https://example.test/catalog/figures/swr_fig.webp?v2');
        await pumpUntil(tester, discardedLateV2);

        final after = _resolved(tester);
        expect(after.imageVersion, 'v1');
        expect(after.imageRef, v1.imageRef);

        await tester.pumpWidget(const SizedBox.shrink());
      },
    );

    testWidgets('dispose during resolve does not throw', (tester) async {
      final entered = Completer<void>();
      final pending = Completer<String?>();
      final discarded = discardedSignal();
      CatalogImageResolver.getDownloadUrlOverride = (path) async {
        if (!path.endsWith('.webp')) return null;
        if (!entered.isCompleted) entered.complete();
        return pending.future;
      };

      CatalogBundleCache.prime(
        CatalogSeedBundle(
          brands: const [],
          ips: const [],
          series: const [],
          figures: [_figure(imageKey: 'swr_fig', imageVersion: 'v1')],
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
      await tester.pump();
      await pumpUntil(tester, entered);

      await tester.pumpWidget(const SizedBox.shrink());
      pending.complete('https://example.test/catalog/figures/swr_fig.webp');
      await pumpUntil(tester, discarded);
    });

    testWidgets(
      'exhausted retries with no prior art show placeholder',
      (tester) async {
        final applied = Completer<String?>();
        catalogImageFromKeyDebugOnResolveApplied = (key, v) {
          if (key == 'swr_fig' && !applied.isCompleted) applied.complete(v);
        };
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
        await pumpUntil(tester, applied);

        expect(find.byType(CollectibleFigurePlaceholder), findsOneWidget);
        expect(find.byType(CatalogResolvedImage), findsNothing);

        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  });
}
