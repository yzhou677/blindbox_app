import 'package:blindbox_app/core/theme/app_theme.dart';
import 'package:blindbox_app/features/official_feed/application/official_feed_providers.dart';
import 'package:blindbox_app/features/official_feed/data/official_feed_mapper.dart';
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
  required String sourceLabel,
  required String officialUrl,
}) {
  return OfficialFeedItem(
    id: id,
    sourceId: sourceId,
    sourceLabel: sourceLabel,
    title: '$sourceLabel title $id',
    imageUrl: 'https://cdn.example.com/$id.png',
    officialUrl: officialUrl,
    publishedAt: DateTime.utc(2026, 7, 1),
    contentHash: 'hash_$id',
  );
}

Map<String, dynamic> _doc({
  required String sourceId,
  required String sourceLabel,
  required String officialUrl,
  required String imageUrl,
}) {
  return {
    'id': 'doc_$sourceId',
    'sourceId': sourceId,
    'sourceLabel': sourceLabel,
    'title': '$sourceLabel drop',
    'imageUrl': imageUrl,
    'officialUrl': officialUrl,
    'publishedAt': Timestamp.fromDate(DateTime.utc(2026, 7, 1)),
    'status': 'active',
    'contentHash': 'hash_$sourceId',
  };
}

OfficialFeedCatalog _threeBrandCatalog() {
  return OfficialFeedCatalog({
    OfficialFeedSources.popmartUs: [
      _item(
        id: 'pm1',
        sourceId: OfficialFeedSources.popmartUs,
        sourceLabel: 'POP MART',
        officialUrl: 'https://www.popmart.com/us/products/6278/crybaby-series',
      ),
    ],
    OfficialFeedSources.tntspaceUs: [
      _item(
        id: 'tnt1',
        sourceId: OfficialFeedSources.tntspaceUs,
        sourceLabel: 'TNT SPACE',
        officialUrl: 'https://www.tntspace.com/us/products/dora',
      ),
    ],
    OfficialFeedSources.toptoyUs: [
      _item(
        id: 'tt1',
        sourceId: OfficialFeedSources.toptoyUs,
        sourceLabel: 'TOP TOY',
        officialUrl: 'https://gotoptoy.com/products/nommi',
      ),
    ],
  });
}

void main() {
  group('OfficialFeedSources', () {
    test('displayLabel maps curated ids', () {
      expect(
        OfficialFeedSources.displayLabel(OfficialFeedSources.popmartUs),
        'POP MART',
      );
      expect(
        OfficialFeedSources.displayLabel(OfficialFeedSources.tntspaceUs),
        'TNT SPACE',
      );
      expect(
        OfficialFeedSources.displayLabel(OfficialFeedSources.toptoyUs),
        'TOP TOY',
      );
      expect(
        OfficialFeedSources.displayLabel('unknown_brand'),
        'unknown_brand',
      );
    });

    test('curatedHomeSources order is POP MART → TNT → TOP TOY', () {
      expect(OfficialFeedSources.curatedHomeSources, [
        OfficialFeedSources.popmartUs,
        OfficialFeedSources.tntspaceUs,
        OfficialFeedSources.toptoyUs,
      ]);
    });

    test('hides chips when fewer than two sources are available', () {
      expect(OfficialFeedSources.shouldShowBrandFilters({}), isFalse);
      expect(
        OfficialFeedSources.shouldShowBrandFilters({
          OfficialFeedSources.popmartUs,
        }),
        isFalse,
      );
      expect(
        OfficialFeedSources.shouldShowBrandFilters({
          OfficialFeedSources.tntspaceUs,
        }),
        isFalse,
      );
      expect(
        OfficialFeedSources.shouldShowBrandFilters({
          OfficialFeedSources.toptoyUs,
        }),
        isFalse,
      );
    });

    test('shows chips when two or more sources are available', () {
      expect(
        OfficialFeedSources.shouldShowBrandFilters({
          OfficialFeedSources.popmartUs,
          OfficialFeedSources.tntspaceUs,
        }),
        isTrue,
      );
      expect(
        OfficialFeedSources.shouldShowBrandFilters({
          OfficialFeedSources.popmartUs,
          OfficialFeedSources.toptoyUs,
        }),
        isTrue,
      );
      expect(
        OfficialFeedSources.shouldShowBrandFilters({
          OfficialFeedSources.tntspaceUs,
          OfficialFeedSources.toptoyUs,
        }),
        isTrue,
      );
      expect(
        OfficialFeedSources.shouldShowBrandFilters({
          OfficialFeedSources.popmartUs,
          OfficialFeedSources.tntspaceUs,
          OfficialFeedSources.toptoyUs,
        }),
        isTrue,
      );
    });

    test('orderedAvailableSources follows curated order', () {
      expect(
        OfficialFeedSources.orderedAvailableSources({
          OfficialFeedSources.toptoyUs,
          OfficialFeedSources.popmartUs,
        }),
        [OfficialFeedSources.popmartUs, OfficialFeedSources.toptoyUs],
      );
    });

    test(
      'resolveSelection preserves preferred or falls back in curated order',
      () {
        expect(
          OfficialFeedSources.resolveSelection(
            availableSourceIds: {
              OfficialFeedSources.tntspaceUs,
              OfficialFeedSources.popmartUs,
            },
          ),
          OfficialFeedSources.popmartUs,
        );
        expect(
          OfficialFeedSources.resolveSelection(
            availableSourceIds: {OfficialFeedSources.toptoyUs},
            preferred: OfficialFeedSources.tntspaceUs,
          ),
          OfficialFeedSources.toptoyUs,
        );
        expect(
          OfficialFeedSources.resolveSelection(
            availableSourceIds: {
              OfficialFeedSources.tntspaceUs,
              OfficialFeedSources.toptoyUs,
            },
            preferred: OfficialFeedSources.toptoyUs,
          ),
          OfficialFeedSources.toptoyUs,
        );
        expect(
          OfficialFeedSources.resolveSelection(availableSourceIds: {}),
          isNull,
        );
        expect(
          OfficialFeedSources.resolveSelection(
            availableSourceIds: {OfficialFeedSources.tntspaceUs},
            preferred: OfficialFeedSources.popmartUs,
          ),
          OfficialFeedSources.tntspaceUs,
        );
      },
    );
  });

  group('OfficialFeedCatalog', () {
    test('availableSources ignores empty lists and orders curated brands', () {
      final catalog = OfficialFeedCatalog({
        OfficialFeedSources.popmartUs: [
          _item(
            id: 'pm1',
            sourceId: OfficialFeedSources.popmartUs,
            sourceLabel: 'POP MART',
            officialUrl:
                'https://www.popmart.com/us/products/6278/crybaby-series',
          ),
        ],
        OfficialFeedSources.tntspaceUs: const [],
        OfficialFeedSources.toptoyUs: [
          _item(
            id: 'tt1',
            sourceId: OfficialFeedSources.toptoyUs,
            sourceLabel: 'TOP TOY',
            officialUrl: 'https://gotoptoy.com/products/nommi',
          ),
        ],
      });

      expect(catalog.availableSources, [
        OfficialFeedSources.popmartUs,
        OfficialFeedSources.toptoyUs,
      ]);
      expect(catalog.hasAnyItems, isTrue);
      expect(catalog.showBrandFilters, isTrue);
      expect(catalog.itemsFor(OfficialFeedSources.tntspaceUs), isEmpty);
      expect(catalog.itemsFor(OfficialFeedSources.popmartUs), hasLength(1));
    });

    test('empty catalog has no items and no filters', () {
      expect(OfficialFeedCatalog.empty.hasAnyItems, isFalse);
      expect(OfficialFeedCatalog.empty.showBrandFilters, isFalse);
      expect(OfficialFeedCatalog.empty.availableSources, isEmpty);
      expect(
        OfficialFeedSources.resolveSelection(
          availableSourceIds: OfficialFeedCatalog.empty.availableSources,
        ),
        isNull,
      );
    });
  });

  group('OfficialFeedCopy', () {
    test('section title and brand-aware subtitle', () {
      expect(OfficialFeedCopy.sectionTitle, 'Official feeds');
      expect(
        OfficialFeedCopy.sectionSubtitleFor(OfficialFeedSources.tntspaceUs),
        'News, campaigns, and links from TNT SPACE',
      );
      expect(
        OfficialFeedCopy.sectionSubtitleFor(OfficialFeedSources.toptoyUs),
        'News, campaigns, and links from TOP TOY',
      );
    });
  });

  group('officialFeedSourceLogoAsset', () {
    test('all three curated brands have bundled logos', () {
      expect(
        officialFeedSourceLogoAsset(OfficialFeedSources.popmartUs),
        'assets/official_feed/popmart_logo.png',
      );
      expect(
        officialFeedSourceLogoAsset(OfficialFeedSources.tntspaceUs),
        'assets/official_feed/tntspace_logo.png',
      );
      expect(
        officialFeedSourceLogoAsset(OfficialFeedSources.toptoyUs),
        'assets/official_feed/toptoy_logo.png',
      );
      expect(officialFeedSourceLogoAsset('other'), isNull);
    });
  });

  group('officialFeedHostLabel', () {
    test('strips www and handles empty', () {
      expect(
        officialFeedHostLabel('https://www.tntspace.com/us/products/a'),
        'tntspace.com',
      );
      expect(
        officialFeedHostLabel('https://gotoptoy.com/products/a'),
        'gotoptoy.com',
      );
      expect(officialFeedHostLabel(''), '');
    });
  });

  group('mapOfficialFeedItem multi-brand destinations', () {
    test('accepts TNT SPACE product URL', () {
      final item = mapOfficialFeedItem(
        'tnt',
        _doc(
          sourceId: OfficialFeedSources.tntspaceUs,
          sourceLabel: 'TNT SPACE',
          officialUrl: 'https://www.tntspace.com/us/products/zoraa-castle',
          imageUrl: 'https://cdn.example.com/tnt.png',
        ),
      );
      expect(item, isNotNull);
      expect(item!.sourceId, OfficialFeedSources.tntspaceUs);
    });

    test('accepts TOP TOY storefront URL on gotoptoy and toptoyglobal', () {
      expect(
        mapOfficialFeedItem(
          'tt',
          _doc(
            sourceId: OfficialFeedSources.toptoyUs,
            sourceLabel: 'TOP TOY',
            officialUrl: 'https://gotoptoy.com/products/nommi-series',
            imageUrl: 'https://cdn.example.com/tt.png',
          ),
        ),
        isNotNull,
      );
      expect(
        mapOfficialFeedItem(
          'tt_global',
          _doc(
            sourceId: OfficialFeedSources.toptoyUs,
            sourceLabel: 'TOP TOY',
            officialUrl: 'https://www.toptoyglobal.com/products/hello-kitty',
            imageUrl: 'https://cdn.example.com/tt2.png',
          ),
        ),
        isNotNull,
      );
    });

    test('accepts Instagram posts for TNT SPACE and TOP TOY', () {
      expect(
        mapOfficialFeedItem(
          'tnt_ig',
          _doc(
            sourceId: OfficialFeedSources.tntspaceUs,
            sourceLabel: 'TNT SPACE',
            officialUrl: 'https://www.instagram.com/p/DbSjwQwihMe/',
            imageUrl: 'https://cdn.example.com/tnt_ig.png',
          ),
        ),
        isNotNull,
      );
      expect(
        mapOfficialFeedItem(
          'tt_ig',
          _doc(
            sourceId: OfficialFeedSources.toptoyUs,
            sourceLabel: 'TOP TOY',
            officialUrl: 'https://www.instagram.com/reel/DbYEJVrj03N/',
            imageUrl: 'https://cdn.example.com/tt_ig.png',
          ),
        ),
        isNotNull,
      );
    });

    test('rejects TOP TOY homepage and cross-brand POP MART URL', () {
      expect(
        mapOfficialFeedItem(
          'tt_home',
          _doc(
            sourceId: OfficialFeedSources.toptoyUs,
            sourceLabel: 'TOP TOY',
            officialUrl: 'https://gotoptoy.com/us',
            imageUrl: 'https://cdn.example.com/tt.png',
          ),
        ),
        isNull,
      );
      expect(
        mapOfficialFeedItem(
          'tnt_wrong',
          _doc(
            sourceId: OfficialFeedSources.tntspaceUs,
            sourceLabel: 'TNT SPACE',
            officialUrl:
                'https://www.popmart.com/us/products/6278/crybaby-series',
            imageUrl: 'https://cdn.example.com/tnt.png',
          ),
        ),
        isNull,
      );
    });

    test('rejects TNT SPACE region root', () {
      expect(
        mapOfficialFeedItem(
          'tnt_home',
          _doc(
            sourceId: OfficialFeedSources.tntspaceUs,
            sourceLabel: 'TNT SPACE',
            officialUrl: 'https://www.tntspace.com/us',
            imageUrl: 'https://cdn.example.com/tnt.png',
          ),
        ),
        isNull,
      );
    });

    test('isValidOfficialFeedDestination mirrors mapper rules', () {
      expect(
        isValidOfficialFeedDestination(
          Uri.parse('https://www.instagram.com/p/Abc123/'),
          OfficialFeedSources.tntspaceUs,
        ),
        isTrue,
      );
      expect(
        isValidOfficialFeedDestination(
          Uri.parse('https://gotoptoy.com/'),
          OfficialFeedSources.toptoyUs,
        ),
        isFalse,
      );
      expect(
        isValidOfficialFeedDestination(
          Uri.parse(
            'https://www.tntspace.com/us/collections/Rayan/products/C723A',
          ),
          OfficialFeedSources.tntspaceUs,
        ),
        isTrue,
      );
    });
  });

  group('OfficialFeedSelectedSourceNotifier', () {
    test('select ignores unknown ids and no-ops on same id', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(
        officialFeedSelectedSourceProvider.notifier,
      );
      expect(
        container.read(officialFeedSelectedSourceProvider),
        OfficialFeedSources.popmartUs,
      );

      notifier.select('not_a_brand');
      expect(
        container.read(officialFeedSelectedSourceProvider),
        OfficialFeedSources.popmartUs,
      );

      notifier.select(OfficialFeedSources.tntspaceUs);
      expect(
        container.read(officialFeedSelectedSourceProvider),
        OfficialFeedSources.tntspaceUs,
      );

      notifier.select(OfficialFeedSources.tntspaceUs);
      expect(
        container.read(officialFeedSelectedSourceProvider),
        OfficialFeedSources.tntspaceUs,
      );
    });
  });

  group('OfficialFeedSection brand filters', () {
    testWidgets('POP MART only hides brand chips', (tester) async {
      final catalog = OfficialFeedCatalog({
        OfficialFeedSources.popmartUs: [
          _item(
            id: 'pm1',
            sourceId: OfficialFeedSources.popmartUs,
            sourceLabel: 'POP MART',
            officialUrl:
                'https://www.popmart.com/us/products/6278/crybaby-series',
          ),
        ],
      });

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
      expect(
        find.byKey(const Key('official_feed_brand_filters')),
        findsNothing,
      );
      expect(find.textContaining('from POP MART'), findsOneWidget);
    });

    testWidgets('all three brands show chips and switch the visible feed', (
      tester,
    ) async {
      final catalog = _threeBrandCatalog();

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
      expect(find.text('POP MART'), findsWidgets);
      expect(find.text('TNT SPACE'), findsWidgets);
      expect(find.text('TOP TOY'), findsWidgets);
      expect(find.text('POP MART title pm1'), findsOneWidget);
      expect(find.text('TNT SPACE title tnt1'), findsNothing);

      await tester.tap(
        find.byKey(const Key('official_feed_brand_tntspace_us')),
      );
      await tester.pumpAndSettle();

      expect(find.text('TNT SPACE title tnt1'), findsOneWidget);
      expect(find.text('POP MART title pm1'), findsNothing);
      expect(find.textContaining('from TNT SPACE'), findsOneWidget);

      await tester.tap(find.byKey(const Key('official_feed_brand_toptoy_us')));
      await tester.pumpAndSettle();

      expect(find.text('TOP TOY title tt1'), findsOneWidget);
      expect(find.textContaining('from TOP TOY'), findsOneWidget);
    });

    testWidgets('empty catalog shows nothing (no chips)', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            officialFeedCatalogProvider.overrideWith(
              (_) async => OfficialFeedCatalog.empty,
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const Scaffold(body: OfficialFeedSection()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(OfficialFeedCopy.sectionTitle), findsNothing);
      expect(
        find.byKey(const Key('official_feed_brand_filters')),
        findsNothing,
      );
    });

    testWidgets('falls back to TNT when preferred POP MART is empty', (
      tester,
    ) async {
      final catalog = OfficialFeedCatalog({
        OfficialFeedSources.popmartUs: const [],
        OfficialFeedSources.tntspaceUs: [
          _item(
            id: 'tnt1',
            sourceId: OfficialFeedSources.tntspaceUs,
            sourceLabel: 'TNT SPACE',
            officialUrl: 'https://www.tntspace.com/us/products/dora',
          ),
        ],
        OfficialFeedSources.toptoyUs: const [],
      });

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
        findsNothing,
      );
      expect(find.text('TNT SPACE title tnt1'), findsOneWidget);
      expect(find.textContaining('from TNT SPACE'), findsOneWidget);
      expect(find.text('POP MART title'), findsNothing);
    });

    testWidgets('keeps selection after refresh when brand still available', (
      tester,
    ) async {
      final catalog = _threeBrandCatalog();

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
      expect(find.text('TOP TOY title tt1'), findsOneWidget);

      final container = ProviderScope.containerOf(
        tester.element(find.byType(OfficialFeedSection)),
      );
      container.invalidate(officialFeedCatalogProvider);
      await tester.pumpAndSettle();

      expect(find.text('TOP TOY title tt1'), findsOneWidget);
      expect(find.textContaining('from TOP TOY'), findsOneWidget);
    });

    testWidgets('falls back when selected brand becomes empty after refresh', (
      tester,
    ) async {
      var catalog = _threeBrandCatalog();

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

      await tester.tap(
        find.byKey(const Key('official_feed_brand_tntspace_us')),
      );
      await tester.pumpAndSettle();
      expect(find.text('TNT SPACE title tnt1'), findsOneWidget);

      catalog = OfficialFeedCatalog({
        OfficialFeedSources.popmartUs: [
          _item(
            id: 'pm1',
            sourceId: OfficialFeedSources.popmartUs,
            sourceLabel: 'POP MART',
            officialUrl:
                'https://www.popmart.com/us/products/6278/crybaby-series',
          ),
        ],
        OfficialFeedSources.tntspaceUs: const [],
        OfficialFeedSources.toptoyUs: [
          _item(
            id: 'tt1',
            sourceId: OfficialFeedSources.toptoyUs,
            sourceLabel: 'TOP TOY',
            officialUrl: 'https://gotoptoy.com/products/nommi',
          ),
        ],
      });

      final container = ProviderScope.containerOf(
        tester.element(find.byType(OfficialFeedSection)),
      );
      container.invalidate(officialFeedCatalogProvider);
      await tester.pumpAndSettle();

      // Preferred TNT is empty → resolve to POP MART; chips for pm+tt only.
      expect(find.text('POP MART title pm1'), findsOneWidget);
      expect(find.text('TNT SPACE title tnt1'), findsNothing);
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
    });

    testWidgets('single POP MART source hides chips', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            officialFeedCatalogProvider.overrideWith(
              (_) async => OfficialFeedCatalog({
                OfficialFeedSources.popmartUs: [
                  _item(
                    id: 'pm1',
                    sourceId: OfficialFeedSources.popmartUs,
                    sourceLabel: 'POP MART',
                    officialUrl:
                        'https://www.popmart.com/us/products/6278/crybaby-series',
                  ),
                ],
                OfficialFeedSources.tntspaceUs: const [],
                OfficialFeedSources.toptoyUs: const [],
              }),
            ),
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
        findsNothing,
      );
      expect(find.text('POP MART title pm1'), findsOneWidget);
    });

    testWidgets('single TNT SPACE source hides chips and is selected', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            officialFeedCatalogProvider.overrideWith(
              (_) async => OfficialFeedCatalog({
                OfficialFeedSources.popmartUs: const [],
                OfficialFeedSources.tntspaceUs: [
                  _item(
                    id: 'tnt1',
                    sourceId: OfficialFeedSources.tntspaceUs,
                    sourceLabel: 'TNT SPACE',
                    officialUrl: 'https://www.tntspace.com/us/products/dora',
                  ),
                ],
                OfficialFeedSources.toptoyUs: const [],
              }),
            ),
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
        findsNothing,
      );
      expect(find.text('TNT SPACE title tnt1'), findsOneWidget);
      expect(find.textContaining('from TNT SPACE'), findsOneWidget);
      expect(find.textContaining('from POP MART'), findsNothing);
    });

    testWidgets('single TOP TOY source hides chips and is selected', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            officialFeedCatalogProvider.overrideWith(
              (_) async => OfficialFeedCatalog({
                OfficialFeedSources.popmartUs: const [],
                OfficialFeedSources.tntspaceUs: const [],
                OfficialFeedSources.toptoyUs: [
                  _item(
                    id: 'tt1',
                    sourceId: OfficialFeedSources.toptoyUs,
                    sourceLabel: 'TOP TOY',
                    officialUrl: 'https://gotoptoy.com/products/nommi',
                  ),
                ],
              }),
            ),
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
        findsNothing,
      );
      expect(find.text('TOP TOY title tt1'), findsOneWidget);
    });

    testWidgets('two-source combo shows only available chips', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            officialFeedCatalogProvider.overrideWith(
              (_) async => OfficialFeedCatalog({
                OfficialFeedSources.popmartUs: [
                  _item(
                    id: 'pm1',
                    sourceId: OfficialFeedSources.popmartUs,
                    sourceLabel: 'POP MART',
                    officialUrl:
                        'https://www.popmart.com/us/products/6278/crybaby-series',
                  ),
                ],
                OfficialFeedSources.tntspaceUs: const [],
                OfficialFeedSources.toptoyUs: [
                  _item(
                    id: 'tt1',
                    sourceId: OfficialFeedSources.toptoyUs,
                    sourceLabel: 'TOP TOY',
                    officialUrl: 'https://gotoptoy.com/products/nommi',
                  ),
                ],
              }),
            ),
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
      expect(
        find.byKey(const Key('official_feed_brand_popmart_us')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('official_feed_brand_toptoy_us')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('official_feed_brand_tntspace_us')),
        findsNothing,
      );
    });

    testWidgets('brand chips stay compact (≤34dp tall)', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            officialFeedCatalogProvider.overrideWith(
              (_) async => _threeBrandCatalog(),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const Scaffold(body: OfficialFeedSection()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final chip = tester.getSize(
        find.byKey(const Key('official_feed_brand_popmart_us')),
      );
      expect(chip.height, lessThanOrEqualTo(34));
      expect(chip.height, greaterThanOrEqualTo(26));
    });
  });
}
