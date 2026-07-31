import 'package:blindbox_app/features/catalog/catalog_bundle.dart';
import 'package:blindbox_app/features/catalog/models/catalog_brand.dart';
import 'package:blindbox_app/features/catalog/models/catalog_figure.dart'
    as catalog_figure;
import 'package:blindbox_app/features/catalog/models/catalog_ip.dart';
import 'package:blindbox_app/features/catalog/models/catalog_series.dart'
    as catalog_series;
import 'package:blindbox_app/features/collection/application/collection_shelf_ui_prefs_provider.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/collection/domain/series_completion_resolution.dart';
import 'package:blindbox_app/features/collection/presentation/collection_shelf_card_content.dart';
import 'package:blindbox_app/features/collection/presentation/collection_shelf_layout.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/collection_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final allAvailable = CollectionShelfCardContentField.values.toSet();

  group('Shared Card Content preference logic', () {
    test('1. default selection is empty and shared across layouts', () {
      const prefs = CollectionShelfUiPrefs();
      expect(prefs.cardContentSelection, isEmpty);
      expect(prefs.cardContent, CollectionShelfCardContentPrefs.empty);
    });

    test('2. one shared selection — not per-layout', () {
      const cardContent = CollectionShelfCardContentPrefs(
        CollectionShelfCardContentSelection([
          CollectionShelfCardContentField.brand,
          CollectionShelfCardContentField.ip,
        ]),
      );
      const prefs = CollectionShelfUiPrefs(
        layout: CollectionShelfLayout.grid,
        cardContent: cardContent,
      );
      expect(prefs.cardContentSelection.ordered, [
        CollectionShelfCardContentField.brand,
        CollectionShelfCardContentField.ip,
      ]);
      // Layout copy does not own a separate Card Content map.
      expect(
        prefs.copyWith(layout: CollectionShelfLayout.list).cardContent,
        cardContent,
      );
      expect(
        prefs.copyWith(layout: CollectionShelfLayout.compactGrid).cardContent,
        cardContent,
      );
    });

    test('3/4. up to two options; third cannot be added', () {
      var sel = const CollectionShelfCardContentSelection();
      sel = sel.toggle(
        CollectionShelfCardContentField.brand,
        available: allAvailable,
      );
      sel = sel.toggle(
        CollectionShelfCardContentField.ip,
        available: allAvailable,
      );
      expect(sel.ordered, hasLength(2));
      final blocked = sel.toggle(
        CollectionShelfCardContentField.wishlistCount,
        available: allAvailable,
      );
      expect(blocked, sel);
      expect(
        blocked.ordered,
        isNot(contains(CollectionShelfCardContentField.wishlistCount)),
      );
    });

    test(
      '5/6. selected option can be removed at limit; then others re-enable',
      () {
        var sel = const CollectionShelfCardContentSelection([
          CollectionShelfCardContentField.brand,
          CollectionShelfCardContentField.ip,
        ]);
        sel = sel.toggle(
          CollectionShelfCardContentField.brand,
          available: allAvailable,
        );
        expect(sel.ordered, [CollectionShelfCardContentField.ip]);
        sel = sel.toggle(
          CollectionShelfCardContentField.wishlistCount,
          available: allAvailable,
        );
        expect(sel.ordered, [
          CollectionShelfCardContentField.ip,
          CollectionShelfCardContentField.wishlistCount,
        ]);
      },
    );

    test('7. stored values exceeding two are sanitized deterministically', () {
      const oversized = CollectionShelfCardContentSelection([
        CollectionShelfCardContentField.brand,
        CollectionShelfCardContentField.ip,
        CollectionShelfCardContentField.wishlistCount,
      ]);
      final sanitized = oversized.sanitizePreservingUnavailable(allAvailable);
      expect(sanitized.ordered, [
        CollectionShelfCardContentField.brand,
        CollectionShelfCardContentField.ip,
      ]);
    });

    test('8. unknown serialized values are ignored safely', () {
      final sel = CollectionShelfCardContentSelection.decode([
        'brand',
        'not_a_field',
        'ip',
        42,
      ]);
      expect(sel.ordered, [
        CollectionShelfCardContentField.brand,
        CollectionShelfCardContentField.ip,
      ]);
    });

    test('9. Card Content and Layout persist independently', () async {
      SharedPreferences.setMockInitialValues({});
      await CollectionShelfUiPrefsStorage.save(
        const CollectionShelfUiPrefs(
          layout: CollectionShelfLayout.compactGrid,
          cardContent: CollectionShelfCardContentPrefs(
            CollectionShelfCardContentSelection([
              CollectionShelfCardContentField.usReleaseDate,
              CollectionShelfCardContentField.duplicateCount,
            ]),
          ),
        ),
      );
      final loaded = await CollectionShelfUiPrefsStorage.load();
      expect(loaded.layout, CollectionShelfLayout.compactGrid);
      expect(loaded.cardContentSelection.ordered, [
        CollectionShelfCardContentField.usReleaseDate,
        CollectionShelfCardContentField.duplicateCount,
      ]);
    });

    test('legacy per-layout map migrates via preferred layout', () {
      final decoded = CollectionShelfUiPrefsCodec.decode(
        '{"sort":"recentlyAdded","layout":"list","cardContent":'
        '{"grid":["brand"],"list":["ip","wishlist_count"],'
        '"compactGrid":["duplicate_count"]}}',
      );
      expect(decoded.layout, CollectionShelfLayout.list);
      expect(decoded.cardContentSelection.ordered, [
        CollectionShelfCardContentField.ip,
        CollectionShelfCardContentField.wishlistCount,
      ]);
    });

    test('legacy map falls back to first non-empty layout order', () {
      final prefs = CollectionShelfCardContentPrefs.decode({
        'grid': <String>[],
        'compactGrid': ['brand', 'ip'],
        'list': <String>[],
      }, preferredLayout: CollectionShelfLayout.grid);
      expect(prefs.selection.ordered, [
        CollectionShelfCardContentField.brand,
        CollectionShelfCardContentField.ip,
      ]);
    });

    test('encode writes flat shared array, not by-layout map', () {
      final encoded = CollectionShelfUiPrefsCodec.encode(
        const CollectionShelfUiPrefs(
          layout: CollectionShelfLayout.list,
          cardContent: CollectionShelfCardContentPrefs(
            CollectionShelfCardContentSelection([
              CollectionShelfCardContentField.brand,
              CollectionShelfCardContentField.ip,
            ]),
          ),
        ),
      );
      expect(encoded, contains('"cardContent":["brand","ip"]'));
      expect(encoded, isNot(contains('"grid"')));
      final decoded = CollectionShelfUiPrefsCodec.decode(encoded);
      expect(decoded.layout, CollectionShelfLayout.list);
      expect(decoded.cardContentSelection.ordered, [
        CollectionShelfCardContentField.brand,
        CollectionShelfCardContentField.ip,
      ]);
    });
  });

  group('Notifier: Layout vs Card Content independence', () {
    test('switching layout does not change Card Content', () async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(collectionShelfUiPrefsProvider.notifier);

      notifier.setCardContent(
        const CollectionShelfCardContentSelection([
          CollectionShelfCardContentField.brand,
          CollectionShelfCardContentField.ip,
        ]),
      );
      expect(
        container.read(collectionShelfUiPrefsProvider).layout,
        CollectionShelfLayout.grid,
      );

      notifier.setLayout(CollectionShelfLayout.list);
      expect(
        container
            .read(collectionShelfUiPrefsProvider)
            .cardContentSelection
            .ordered,
        [
          CollectionShelfCardContentField.brand,
          CollectionShelfCardContentField.ip,
        ],
      );

      notifier.setLayout(CollectionShelfLayout.compactGrid);
      expect(
        container
            .read(collectionShelfUiPrefsProvider)
            .cardContentSelection
            .ordered,
        [
          CollectionShelfCardContentField.brand,
          CollectionShelfCardContentField.ip,
        ],
      );
      expect(
        container.read(collectionShelfUiPrefsProvider).layout,
        CollectionShelfLayout.compactGrid,
      );
    });

    test('changing Card Content does not change Layout', () {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(collectionShelfUiPrefsProvider.notifier);

      notifier.setLayout(CollectionShelfLayout.list);
      notifier.setCardContent(
        const CollectionShelfCardContentSelection([
          CollectionShelfCardContentField.wishlistCount,
        ]),
      );
      expect(
        container.read(collectionShelfUiPrefsProvider).layout,
        CollectionShelfLayout.list,
      );
      expect(
        container
            .read(collectionShelfUiPrefsProvider)
            .cardContentSelection
            .ordered,
        [CollectionShelfCardContentField.wishlistCount],
      );
    });

    test(
      'setLayout does not rewrite Card Content when only layout changes',
      () async {
        SharedPreferences.setMockInitialValues({});
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final notifier = container.read(
          collectionShelfUiPrefsProvider.notifier,
        );

        notifier.setCardContent(
          const CollectionShelfCardContentSelection([
            CollectionShelfCardContentField.brand,
          ]),
        );
        await Future<void>.delayed(Duration.zero);
        final afterCard = await SharedPreferences.getInstance();
        final encodedAfterCard = afterCard.getString(
          kCollectionShelfUiPrefsKey,
        )!;
        expect(encodedAfterCard, contains('"brand"'));

        notifier.setLayout(CollectionShelfLayout.list);
        await Future<void>.delayed(Duration.zero);
        final afterLayout = await SharedPreferences.getInstance();
        final encodedAfterLayout = afterLayout.getString(
          kCollectionShelfUiPrefsKey,
        )!;
        expect(encodedAfterLayout, contains('"layout":"list"'));
        expect(encodedAfterLayout, contains('"cardContent":["brand"]'));
        // Still a flat shared array — not a per-layout rewrite.
        expect(encodedAfterLayout, isNot(contains('"grid":[')));
      },
    );
  });

  group('Card Content availability + resolution', () {
    late CatalogSeedBundle catalog;
    late List<ShelfSeries> shelf;
    late Map<String, TrackedFigure> states;

    setUp(() {
      catalog = CatalogSeedBundle(
        brands: const [CatalogBrand(id: 'pop_mart', displayName: 'POP MART')],
        ips: const [
          CatalogIp(id: 'hirono', brandId: 'pop_mart', displayName: 'Hirono'),
        ],
        series: const [
          catalog_series.CatalogSeries(
            id: 'cat_dated',
            brandId: 'pop_mart',
            ipId: 'hirono',
            displayName: 'Dated',
            releaseDate: '2024-05-24',
            isBlindBox: true,
            imageKey: 'cat_dated',
          ),
          catalog_series.CatalogSeries(
            id: 'cat_bad_date',
            brandId: 'pop_mart',
            ipId: 'hirono',
            displayName: 'Bad',
            releaseDate: 'not-a-date',
            isBlindBox: true,
            imageKey: 'cat_bad_date',
          ),
        ],
        figures: const [
          catalog_figure.CatalogFigure(
            id: 'cf1',
            seriesId: 'cat_dated',
            brandId: 'pop_mart',
            ipId: 'hirono',
            displayName: 'F',
            isSecret: false,
            sortOrder: 0,
            imageKey: 'cf1',
          ),
        ],
      );

      shelf = [
        testShelfSeries(
          id: 'dated',
          name: 'THE MONSTERS',
          brand: 'POP MART',
          ipName: 'Hirono',
          taxonomyBrandId: 'pop_mart',
          taxonomyIpId: 'hirono',
          catalogTemplateId: 'cat_dated',
          figures: const [
            ShelfFigure(
              id: 'd0',
              seriesId: 'dated',
              name: 'A',
              rarity: 'Regular',
              isSecret: false,
            ),
            ShelfFigure(
              id: 'd1',
              seriesId: 'dated',
              name: 'B',
              rarity: 'Regular',
              isSecret: false,
            ),
          ],
        ),
        testShelfSeries(
          id: 'dimoo',
          name: 'DIMOO',
          brand: 'POP MART',
          ipName: '',
          taxonomyBrandId: 'pop_mart',
          taxonomyIpId: null,
          catalogTemplateId: 'cat_bad_date',
          figures: const [
            ShelfFigure(
              id: 'm0',
              seriesId: 'dimoo',
              name: 'A',
              rarity: 'Regular',
              isSecret: false,
            ),
          ],
        ),
        testShelfSeries(
          id: 'blank_meta',
          name: 'Blank',
          brand: '',
          ipName: '',
          taxonomyBrandId: null,
          taxonomyIpId: null,
          catalogTemplateId: null,
          figures: const [
            ShelfFigure(
              id: 'b0',
              seriesId: 'blank_meta',
              name: 'A',
              rarity: 'Regular',
              isSecret: false,
            ),
          ],
        ),
      ];

      states = {
        'd0': const TrackedFigure(
          figureId: 'd0',
          state: FigureCollectionState.owned,
          ownedQuantity: 3,
        ),
        'd1': const TrackedFigure(
          figureId: 'd1',
          state: FigureCollectionState.wishlist,
        ),
        'm0': const TrackedFigure(
          figureId: 'm0',
          state: FigureCollectionState.owned,
          ownedQuantity: 1,
        ),
        'b0': const TrackedFigure(
          figureId: 'b0',
          state: FigureCollectionState.owned,
          ownedQuantity: 1,
        ),
      };
    });

    test('11-15. availability hides empty Brand/IP/date/zero counts', () {
      final available = availableCollectionShelfCardContentFields(
        shelfSeries: shelf,
        figureStates: states,
        catalog: catalog,
      );
      expect(
        available,
        contains(CollectionShelfCardContentField.usReleaseDate),
      );
      expect(available, contains(CollectionShelfCardContentField.brand));
      expect(available, contains(CollectionShelfCardContentField.ip));
      expect(
        available,
        contains(CollectionShelfCardContentField.wishlistCount),
      );
      expect(
        available,
        contains(CollectionShelfCardContentField.duplicateCount),
      );

      final noWishNoDup = availableCollectionShelfCardContentFields(
        shelfSeries: [shelf[1]],
        figureStates: states,
        catalog: catalog,
      );
      expect(
        noWishNoDup,
        isNot(contains(CollectionShelfCardContentField.wishlistCount)),
      );
      expect(
        noWishNoDup,
        isNot(contains(CollectionShelfCardContentField.duplicateCount)),
      );
      expect(
        noWishNoDup,
        isNot(contains(CollectionShelfCardContentField.usReleaseDate)),
      );
      expect(noWishNoDup, contains(CollectionShelfCardContentField.brand));
      expect(noWishNoDup, isNot(contains(CollectionShelfCardContentField.ip)));
    });

    test(
      '16. unavailable saved prefs preserved and do not block selection',
      () {
        const saved = CollectionShelfCardContentSelection([
          CollectionShelfCardContentField.usReleaseDate,
          CollectionShelfCardContentField.brand,
        ]);
        final available = {
          CollectionShelfCardContentField.brand,
          CollectionShelfCardContentField.ip,
        };
        expect(saved.availableSelectedCount(available), 1);
        expect(
          saved.canSelect(CollectionShelfCardContentField.ip, available),
          isTrue,
        );
        final next = saved.toggle(
          CollectionShelfCardContentField.ip,
          available: available,
        );
        expect(next.ordered, [
          CollectionShelfCardContentField.usReleaseDate,
          CollectionShelfCardContentField.brand,
          CollectionShelfCardContentField.ip,
        ]);
        final sanitized = next.sanitizePreservingUnavailable(available);
        expect(sanitized.ordered, [
          CollectionShelfCardContentField.usReleaseDate,
          CollectionShelfCardContentField.brand,
          CollectionShelfCardContentField.ip,
        ]);
        final allBack = sanitized.sanitizePreservingUnavailable(allAvailable);
        expect(allBack.ordered, [
          CollectionShelfCardContentField.usReleaseDate,
          CollectionShelfCardContentField.brand,
        ]);
      },
    );

    test('22-26. card lines hide missing values; counts are correct', () {
      const selection = CollectionShelfCardContentSelection([
        CollectionShelfCardContentField.usReleaseDate,
        CollectionShelfCardContentField.brand,
      ]);
      final monsters = resolveCardContentLines(
        selection,
        shelf[0],
        states,
        catalog: catalog,
      );
      expect(monsters.map((l) => l.text).toList(), [
        'U.S. May 24, 2024',
        'POP MART',
      ]);

      final dimoo = resolveCardContentLines(
        selection,
        shelf[1],
        states,
        catalog: catalog,
      );
      expect(dimoo.map((l) => l.text).toList(), ['POP MART']);

      const wishDup = CollectionShelfCardContentSelection([
        CollectionShelfCardContentField.wishlistCount,
        CollectionShelfCardContentField.duplicateCount,
      ]);
      final counts = resolveCardContentLines(wishDup, shelf[0], states);
      expect(counts.map((l) => l.text).toList(), ['1 wished', '2 duplicates']);

      final resolution = resolveSeriesCompletion(shelf[0], states);
      expect(resolution.regularOwnedCount, 1);
      expect(states['d0']!.ownedQuantity, 3);
    });

    test('24. U.S. release wording stays explicit', () {
      expect(
        formatUsReleaseDateCardLine(DateTime(2026, 7, 30)),
        'U.S. Jul 30, 2026',
      );
      expect(formatUsReleaseDateCardLine(null), isNull);
    });

    test('custom shelf releaseDate feeds Card Content without catalog', () {
      final custom = testShelfSeries(
        id: 'custom-dated',
        catalogTemplateId: null,
        brand: 'Independent',
        ipName: 'Picnic',
        releaseDate: '2026-07-30',
      );
      expect(
        seriesHasCardContentValue(
          CollectionShelfCardContentField.usReleaseDate,
          custom,
          const {},
        ),
        isTrue,
      );
      expect(
        resolveCardContentText(
          CollectionShelfCardContentField.usReleaseDate,
          custom,
          const {},
        ),
        'U.S. Jul 30, 2026',
      );
      expect(
        availableCollectionShelfCardContentFields(
          shelfSeries: [custom],
          figureStates: const {},
        ),
        contains(CollectionShelfCardContentField.usReleaseDate),
      );
    });
  });
}
