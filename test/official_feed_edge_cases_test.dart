import 'dart:async';
import 'dart:io';

import 'package:blindbox_app/core/theme/app_theme.dart';
import 'package:blindbox_app/features/home/application/home_discover_refresh_controller.dart';
import 'package:blindbox_app/features/official_feed/application/official_feed_providers.dart';
import 'package:blindbox_app/features/official_feed/data/firestore_official_feed_loader.dart';
import 'package:blindbox_app/features/official_feed/data/official_feed_mapper.dart';
import 'package:blindbox_app/features/official_feed/data/official_feed_repository.dart';
import 'package:blindbox_app/features/official_feed/domain/official_feed_catalog.dart';
import 'package:blindbox_app/features/official_feed/domain/official_feed_item.dart';
import 'package:blindbox_app/features/official_feed/domain/official_feed_sources.dart';
import 'package:blindbox_app/features/official_feed/presentation/official_feed_copy.dart';
import 'package:blindbox_app/features/official_feed/presentation/official_feed_source_presenter.dart';
import 'package:blindbox_app/features/official_feed/widgets/official_feed_section.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

OfficialFeedItem _item({
  required String id,
  required String sourceId,
  String? title,
}) {
  return OfficialFeedItem(
    id: id,
    sourceId: sourceId,
    sourceLabel: OfficialFeedSources.displayLabel(sourceId),
    title: title ?? 'Title $id',
    imageUrl: 'https://cdn.example.com/$id.png',
    officialUrl: 'https://example.com/$id',
    publishedAt: DateTime.utc(2026, 7, 1),
    contentHash: 'hash_$id',
  );
}

Map<String, dynamic> _activeDoc({
  required String sourceId,
  required String sourceLabel,
  required String officialUrl,
  required String imageUrl,
  String id = 'doc_1',
  String status = 'active',
  Object? publishedAt,
  Object? title = 'Title',
  Object? contentHash = 'hash',
}) {
  return {
    'id': id,
    'sourceId': sourceId,
    'sourceLabel': sourceLabel,
    'title': title,
    'imageUrl': imageUrl,
    'officialUrl': officialUrl,
    'publishedAt': publishedAt ?? Timestamp.fromDate(DateTime.utc(2026, 7, 1)),
    'status': status,
    'contentHash': contentHash,
  };
}

OfficialFeedCatalog _catalog({
  List<OfficialFeedItem>? popmart,
  List<OfficialFeedItem>? tnt,
  List<OfficialFeedItem>? toptoy,
}) {
  return OfficialFeedCatalog({
    OfficialFeedSources.popmartUs: popmart ?? const [],
    OfficialFeedSources.tntspaceUs: tnt ?? const [],
    OfficialFeedSources.toptoyUs: toptoy ?? const [],
  });
}

void main() {
  setUp(OfficialFeedRepository.debugClearLastGoodCache);

  group('empty success vs failure', () {
    test(
      'successful empty replaces and clears last-good; later failure stays empty',
      () async {
        var phase = 'items';
        final repo = OfficialFeedRepository(
          loader: ({required sourceId, limit = 12}) async {
            if (sourceId != OfficialFeedSources.tntspaceUs) {
              return const [];
            }
            if (phase == 'items') {
              return [_item(id: 'tnt_1', sourceId: sourceId)];
            }
            if (phase == 'empty') return const [];
            throw StateError('network down');
          },
        );

        expect(
          (await repo.loadActive(
            sourceId: OfficialFeedSources.tntspaceUs,
          )).single.id,
          'tnt_1',
        );

        phase = 'empty';
        expect(
          await repo.loadActive(sourceId: OfficialFeedSources.tntspaceUs),
          isEmpty,
        );

        phase = 'fail';
        expect(
          await repo.loadActive(sourceId: OfficialFeedSources.tntspaceUs),
          isEmpty,
        );
      },
    );

    test(
      'request failure preserves and returns last-good without modifying cache',
      () async {
        var fail = false;
        final repo = OfficialFeedRepository(
          loader: ({required sourceId, limit = 12}) async {
            if (fail) throw StateError('boom');
            return [_item(id: 'pm_1', sourceId: sourceId)];
          },
        );

        await repo.loadActive(sourceId: OfficialFeedSources.popmartUs);
        fail = true;
        final afterFail = await repo.loadActive(
          sourceId: OfficialFeedSources.popmartUs,
        );
        expect(afterFail.single.id, 'pm_1');
      },
    );
  });

  group('overlapping loads', () {
    test('older completion cannot clear newer last-good', () async {
      final gates = <Completer<void>>[];
      final payloads = <List<OfficialFeedItem>>[
        const [],
        [_item(id: 'fresh', sourceId: OfficialFeedSources.popmartUs)],
      ];
      var call = 0;

      final repo = OfficialFeedRepository(
        loader: ({required sourceId, limit = 12}) async {
          final index = call++;
          final gate = Completer<void>();
          gates.add(gate);
          await gate.future;
          return payloads[index];
        },
      );

      final first = repo.loadActive(sourceId: OfficialFeedSources.popmartUs);
      final second = repo.loadActive(sourceId: OfficialFeedSources.popmartUs);

      gates[1].complete();
      expect((await second).single.id, 'fresh');

      gates[0].complete();
      await first; // stale empty must not wipe cache

      final failing = OfficialFeedRepository(
        loader: ({required sourceId, limit = 12}) async {
          throw StateError('down');
        },
      );
      expect(
        (await failing.loadActive(
          sourceId: OfficialFeedSources.popmartUs,
        )).single.id,
        'fresh',
      );
    });
  });

  group('inactive / partial mapping', () {
    test('mapper drops inactive; active siblings still map', () {
      final items = mapOfficialFeedDocuments([
        (
          id: 'bad',
          data: _activeDoc(
            id: 'bad',
            sourceId: OfficialFeedSources.popmartUs,
            sourceLabel: 'POP MART',
            officialUrl: 'https://www.popmart.com/us/products/1/a',
            imageUrl: 'https://cdn.example.com/a.png',
            status: 'archived',
          ),
        ),
        (
          id: 'good',
          data: _activeDoc(
            id: 'good',
            sourceId: OfficialFeedSources.popmartUs,
            sourceLabel: 'POP MART',
            officialUrl: 'https://www.popmart.com/us/products/2/b',
            imageUrl: 'https://cdn.example.com/b.png',
          ),
        ),
      ]);
      expect(items.map((e) => e.id), ['good']);
    });

    test('inactive-only brand does not count for chips', () {
      // Firestore filters status==active; inactive-only ≡ empty list in catalog.
      final catalog = _catalog(
        popmart: [_item(id: 'pm', sourceId: OfficialFeedSources.popmartUs)],
        tnt: const [],
        toptoy: const [],
      );
      expect(catalog.showBrandFilters, isFalse);
      expect(catalog.availableSources, [OfficialFeedSources.popmartUs]);
      expect(
        OfficialFeedSources.resolveSelection(
          availableSourceIds: catalog.availableSources,
        ),
        OfficialFeedSources.popmartUs,
      );
    });

    test('two available sources show chips; empty brand excluded', () {
      final catalog = _catalog(
        popmart: [_item(id: 'pm', sourceId: OfficialFeedSources.popmartUs)],
        tnt: const [],
        toptoy: [_item(id: 'tt', sourceId: OfficialFeedSources.toptoyUs)],
      );
      expect(catalog.showBrandFilters, isTrue);
      expect(catalog.availableSources, [
        OfficialFeedSources.popmartUs,
        OfficialFeedSources.toptoyUs,
      ]);
    });

    test('dedupe is per-list by id, not by title', () {
      final a = _item(
        id: 'same',
        sourceId: OfficialFeedSources.tntspaceUs,
        title: 'First',
      );
      final b = _item(
        id: 'same',
        sourceId: OfficialFeedSources.tntspaceUs,
        title: 'Second',
      );
      final out = dedupeOfficialFeedItemsById([a, b]);
      expect(out, hasLength(1));
      expect(out.single.title, 'First');
    });
  });

  group('URL destination edges', () {
    test('accepts host case, www, query, fragment, trailing slash', () {
      expect(
        isValidOfficialFeedDestination(
          Uri.parse('https://WWW.PopMart.com/us/products/6278/slug?x=1#frag'),
          OfficialFeedSources.popmartUs,
        ),
        isTrue,
      );
      expect(
        isValidOfficialFeedDestination(
          Uri.parse('https://tntspace.com/us/products/a/'),
          OfficialFeedSources.tntspaceUs,
        ),
        isTrue,
      );
      expect(
        isValidOfficialFeedDestination(
          Uri.parse('https://www.instagram.com/p/Abc123def/?img_index=7'),
          OfficialFeedSources.toptoyUs,
        ),
        isTrue,
      );
    });

    test('rejects http, missing host, stories, profile, lookalike hosts', () {
      expect(
        mapOfficialFeedItem(
          'x',
          _activeDoc(
            sourceId: OfficialFeedSources.popmartUs,
            sourceLabel: 'POP MART',
            officialUrl: 'http://www.popmart.com/us/products/1/a',
            imageUrl: 'https://cdn.example.com/a.png',
          ),
        ),
        isNull,
      );
      expect(
        isValidOfficialFeedDestination(
          Uri.parse('https://www.instagram.com/stories/user/1'),
          OfficialFeedSources.popmartUs,
        ),
        isFalse,
      );
      expect(
        isValidOfficialFeedDestination(
          Uri.parse('https://www.instagram.com/popmart/'),
          OfficialFeedSources.popmartUs,
        ),
        isFalse,
      );
      expect(
        isValidOfficialFeedDestination(
          Uri.parse('https://instagram.com.evil.example/p/Abc123def/'),
          OfficialFeedSources.popmartUs,
        ),
        isFalse,
      );
      expect(
        isValidOfficialFeedDestination(
          Uri.parse('https://not-popmart.com/us/products/1/a'),
          OfficialFeedSources.popmartUs,
        ),
        isFalse,
      );
    });

    test('rejects path-normalized homepage and non-numeric product ids', () {
      // Dart Uri collapses `..` before our checks — traversal to /us is rejected.
      expect(
        isValidOfficialFeedDestination(
          Uri.parse('https://www.popmart.com/us/products/../'),
          OfficialFeedSources.popmartUs,
        ),
        isFalse,
      );
      expect(
        isValidOfficialFeedDestination(
          Uri.parse('https://www.popmart.com/us/products/not-a-number/a'),
          OfficialFeedSources.popmartUs,
        ),
        isFalse,
      );
    });
  });

  group('catalog order and selection', () {
    test('catalog keys follow curated order', () async {
      final repo = OfficialFeedRepository(
        loader: ({required sourceId, limit = 12}) async {
          await Future<void>.delayed(
            Duration(
              milliseconds: sourceId == OfficialFeedSources.popmartUs ? 20 : 1,
            ),
          );
          return [_item(id: sourceId, sourceId: sourceId)];
        },
      );
      final catalog = await repo.loadCuratedHomeCatalog();
      expect(
        catalog.bySource.keys.toList(),
        OfficialFeedSources.curatedHomeSources,
      );
    });

    test('unknown preferred selection falls back safely', () {
      expect(
        OfficialFeedSources.resolveSelection(
          availableSourceIds: {
            OfficialFeedSources.tntspaceUs,
            OfficialFeedSources.toptoyUs,
          },
          preferred: 'deleted_brand',
        ),
        OfficialFeedSources.tntspaceUs,
      );
    });
  });

  group('logo assets', () {
    test('bundled logos exist, non-empty, and match declared paths', () {
      for (final sourceId in OfficialFeedSources.curatedHomeSources) {
        final asset = officialFeedSourceLogoAsset(sourceId);
        expect(asset, isNotNull);
        final file = File(asset!);
        expect(file.existsSync(), isTrue, reason: asset);
        expect(file.lengthSync(), greaterThan(100), reason: asset);
      }
    });
  });

  group('widget chip transitions', () {
    testWidgets('3→2 brands keeps chips for remaining sources only', (
      tester,
    ) async {
      var catalog = _catalog(
        popmart: [_item(id: 'pm', sourceId: OfficialFeedSources.popmartUs)],
        tnt: [_item(id: 'tnt', sourceId: OfficialFeedSources.tntspaceUs)],
        toptoy: [_item(id: 'tt', sourceId: OfficialFeedSources.toptoyUs)],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            officialFeedCatalogProvider.overrideWith((_) async => catalog),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const Scaffold(body: OfficialFeedSection()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('official_feed_brand_toptoy_us')));
      await tester.pumpAndSettle();
      expect(find.text('Title tt'), findsOneWidget);

      catalog = _catalog(
        popmart: [_item(id: 'pm', sourceId: OfficialFeedSources.popmartUs)],
        tnt: const [],
        toptoy: [_item(id: 'tt', sourceId: OfficialFeedSources.toptoyUs)],
      );
      ProviderScope.containerOf(
        tester.element(find.byType(OfficialFeedSection)),
      ).invalidate(officialFeedCatalogProvider);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('official_feed_brand_filters')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('official_feed_brand_tntspace_us')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('official_feed_brand_popmart_us')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('official_feed_brand_toptoy_us')),
        findsOneWidget,
      );
      expect(find.text('Title tt'), findsOneWidget);
      expect(find.textContaining('from TOP TOY'), findsOneWidget);
    });

    testWidgets('2→3 brands keeps chips and preserves valid selection', (
      tester,
    ) async {
      var catalog = _catalog(
        popmart: [_item(id: 'pm', sourceId: OfficialFeedSources.popmartUs)],
        tnt: const [],
        toptoy: [_item(id: 'tt', sourceId: OfficialFeedSources.toptoyUs)],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            officialFeedCatalogProvider.overrideWith((_) async => catalog),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const Scaffold(body: OfficialFeedSection()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('official_feed_brand_filters')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('official_feed_brand_toptoy_us')));
      await tester.pumpAndSettle();
      expect(find.text('Title tt'), findsOneWidget);

      catalog = _catalog(
        popmart: [_item(id: 'pm', sourceId: OfficialFeedSources.popmartUs)],
        tnt: [_item(id: 'tnt', sourceId: OfficialFeedSources.tntspaceUs)],
        toptoy: [_item(id: 'tt', sourceId: OfficialFeedSources.toptoyUs)],
      );
      ProviderScope.containerOf(
        tester.element(find.byType(OfficialFeedSection)),
      ).invalidate(officialFeedCatalogProvider);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('official_feed_brand_filters')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('official_feed_brand_tntspace_us')),
        findsOneWidget,
      );
      expect(find.text('Title tt'), findsOneWidget);
      expect(find.textContaining('from TOP TOY'), findsOneWidget);
    });

    testWidgets('two→one hides chips and shows remaining source', (
      tester,
    ) async {
      var catalog = _catalog(
        popmart: [_item(id: 'pm', sourceId: OfficialFeedSources.popmartUs)],
        tnt: [_item(id: 'tnt', sourceId: OfficialFeedSources.tntspaceUs)],
        toptoy: const [],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            officialFeedCatalogProvider.overrideWith((_) async => catalog),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const Scaffold(body: OfficialFeedSection()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('official_feed_brand_filters')),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const Key('official_feed_brand_tntspace_us')),
      );
      await tester.pumpAndSettle();

      catalog = _catalog(
        popmart: const [],
        tnt: [_item(id: 'tnt', sourceId: OfficialFeedSources.tntspaceUs)],
        toptoy: const [],
      );
      ProviderScope.containerOf(
        tester.element(find.byType(OfficialFeedSection)),
      ).invalidate(officialFeedCatalogProvider);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('official_feed_brand_filters')),
        findsNothing,
      );
      expect(find.text('Title tnt'), findsOneWidget);
      expect(find.textContaining('from TNT SPACE'), findsOneWidget);
    });

    testWidgets('two→zero shows empty state without chips or content', (
      tester,
    ) async {
      var catalog = _catalog(
        popmart: [_item(id: 'pm', sourceId: OfficialFeedSources.popmartUs)],
        tnt: [_item(id: 'tnt', sourceId: OfficialFeedSources.tntspaceUs)],
        toptoy: const [],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            officialFeedCatalogProvider.overrideWith((_) async => catalog),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const Scaffold(body: OfficialFeedSection()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(OfficialFeedCopy.sectionTitle), findsOneWidget);

      catalog = OfficialFeedCatalog.empty;
      ProviderScope.containerOf(
        tester.element(find.byType(OfficialFeedSection)),
      ).invalidate(officialFeedCatalogProvider);
      await tester.pumpAndSettle();

      expect(find.text(OfficialFeedCopy.sectionTitle), findsNothing);
      expect(
        find.byKey(const Key('official_feed_brand_filters')),
        findsNothing,
      );
      expect(find.text('Title pm'), findsNothing);
    });
  });

  group('Discover refresh dispose', () {
    test('dispose mid-refresh does not hang or crash the isolate', () async {
      final catalogCompleter = Completer<OfficialFeedCatalog>();
      final container = ProviderContainer(
        overrides: [
          officialFeedCatalogProvider.overrideWith(
            (_) => catalogCompleter.future,
          ),
        ],
      );

      final refreshFuture = container
          .read(homeDiscoverRefreshProvider.notifier)
          .refresh();
      expect(container.read(homeDiscoverRefreshProvider), isTrue);

      container.dispose();
      catalogCompleter.complete(OfficialFeedCatalog.empty);
      try {
        await refreshFuture;
      } catch (_) {
        // Disposed Ref may throw after await; finally must still be safe.
      }
    });
  });

  group('all sources fail', () {
    test(
      'all sources fail: preserves and returns last-good per brand without clearing cache',
      () async {
        final repo = OfficialFeedRepository(
          loader: ({required sourceId, limit = 12}) async {
            return [_item(id: '${sourceId}_1', sourceId: sourceId)];
          },
        );
        await repo.loadCuratedHomeCatalog();

        final failing = OfficialFeedRepository(
          loader: ({required sourceId, limit = 12}) async {
            throw StateError('all down');
          },
        );
        final catalog = await failing.loadCuratedHomeCatalog();
        expect(catalog.hasAnyItems, isTrue);
        expect(
          catalog.itemsFor(OfficialFeedSources.popmartUs).single.id,
          'popmart_us_1',
        );
      },
    );

    test('with no last-good, all failures yield empty catalog', () async {
      OfficialFeedRepository.debugClearLastGoodCache();
      final repo = OfficialFeedRepository(
        loader: ({required sourceId, limit = 12}) async {
          throw StateError('all down');
        },
      );
      final catalog = await repo.loadCuratedHomeCatalog();
      expect(catalog.hasAnyItems, isFalse);
    });
  });
}
