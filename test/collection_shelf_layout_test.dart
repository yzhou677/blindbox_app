import 'package:blindbox_app/core/theme/app_radii.dart';
import 'package:blindbox_app/core/theme/app_theme.dart';
import 'package:blindbox_app/features/collection/application/collection_shelf_ui_prefs_provider.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/collection/presentation/collection_shelf_filters.dart';
import 'package:blindbox_app/features/collection/presentation/collection_shelf_layout.dart';
import 'package:blindbox_app/features/collection/widgets/collection_series_card.dart';
import 'package:blindbox_app/features/collection/widgets/collection_shelf_layout_controls.dart';
import 'package:blindbox_app/features/collection/widgets/collection_shelf_series_layout_host.dart';
import 'package:blindbox_app/features/collection/widgets/collection_shelf_series_list_tile.dart';
import 'package:blindbox_app/features/collection/widgets/collection_shelf_series_rail.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/collection_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CollectionShelfLayout prefs', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('existing users default to Grid', () async {
      final prefs = await CollectionShelfUiPrefsStorage.load();
      expect(prefs.layout, CollectionShelfLayout.grid);
    });

    test('invalid persisted layout falls back to Grid', () {
      final prefs = CollectionShelfUiPrefsCodec.decode(
        '{"sort":"recentlyAdded","layout":"not_a_layout"}',
      );
      expect(prefs.layout, CollectionShelfLayout.grid);
    });

    test('layout selection persists', () async {
      await CollectionShelfUiPrefsStorage.save(
        const CollectionShelfUiPrefs(layout: CollectionShelfLayout.list),
      );
      final prefs = await CollectionShelfUiPrefsStorage.load();
      expect(prefs.layout, CollectionShelfLayout.list);
    });
  });

  group('CollectionShelfSeriesLayoutHost', () {
    late List<ShelfSeries> series;
    late Map<String, TrackedFigure> states;
    late ShelfBrowseProgressLookup progress;

    setUp(() {
      series = [
        testShelfSeries(
          id: 'a',
          name: 'Alpha',
          figures: const [
            ShelfFigure(
              id: 'a1',
              seriesId: 'a',
              name: 'A1',
              rarity: 'Regular',
              isSecret: false,
            ),
            ShelfFigure(
              id: 'a2',
              seriesId: 'a',
              name: 'A2',
              rarity: 'Regular',
              isSecret: false,
            ),
          ],
        ),
      ];
      states = {
        'a1': const TrackedFigure(
          figureId: 'a1',
          state: FigureCollectionState.owned,
          ownedQuantity: 1,
        ),
      };
      progress = ShelfBrowseProgressLookup(states);
    });

    Future<void> pumpLayout(
      WidgetTester tester,
      CollectionShelfLayout layout,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: CollectionShelfSeriesLayoutHost(
                layout: layout,
                series: series,
                figureStates: states,
                progress: progress,
                onOpen: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('Grid renders Series Cards via rail', (tester) async {
      await pumpLayout(tester, CollectionShelfLayout.grid);
      expect(find.byType(CollectionShelfSeriesRail), findsOneWidget);
      expect(find.byType(CollectionSeriesCard), findsOneWidget);
    });

    testWidgets('Compact Grid renders the same filtered data', (tester) async {
      await pumpLayout(tester, CollectionShelfLayout.compactGrid);
      expect(
        find.byKey(const Key('collection_shelf_compact_grid')),
        findsOneWidget,
      );
      expect(find.byType(CollectionSeriesCard), findsOneWidget);
      expect(find.byKey(const ValueKey('a')), findsOneWidget);
    });

    testWidgets('List renders outlined Series Cards', (tester) async {
      await pumpLayout(tester, CollectionShelfLayout.list);
      expect(
        find.byKey(const Key('collection_shelf_series_list')),
        findsOneWidget,
      );
      expect(find.byType(CollectionShelfSeriesListTile), findsOneWidget);
      expect(find.text('Alpha'), findsOneWidget);

      final material = tester.widget<Material>(
        find
            .descendant(
              of: find.byType(CollectionShelfSeriesListTile),
              matching: find.byType(Material),
            )
            .first,
      );
      final shape = material.shape;
      expect(shape, isA<RoundedRectangleBorder>());
      final border = shape! as RoundedRectangleBorder;
      expect(border.side.width, 1);
      expect(border.borderRadius, BorderRadius.circular(AppRadii.inset));
      expect(material.elevation, 0);
    });

    testWidgets('tap works in every layout', (tester) async {
      for (final layout in CollectionShelfLayout.values) {
        var opened = false;
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light(),
            home: Scaffold(
              body: SingleChildScrollView(
                child: CollectionShelfSeriesLayoutHost(
                  layout: layout,
                  series: series,
                  figureStates: states,
                  progress: progress,
                  onOpen: (_) => opened = true,
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.tap(find.byKey(const ValueKey('a')));
        await tester.pump();
        expect(opened, isTrue, reason: layout.name);
      }
    });
  });

  testWidgets('filtered empty state offers clear filters', (tester) async {
    var cleared = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: CollectionShelfFilteredEmptyState(
            onClearFilters: () => cleared = true,
          ),
        ),
      ),
    );
    expect(find.textContaining('No series match'), findsOneWidget);
    await tester.tap(find.byKey(const Key('collection_clear_filters_cta')));
    expect(cleared, isTrue);
  });

  test(
    'active filter count and empty filters remain stable across layout prefs',
    () {
      const filters = CollectionShelfFilters(hasDuplicates: true);
      expect(filters.activeCount, 1);
      expect(
        const CollectionShelfUiPrefs(
          layout: CollectionShelfLayout.compactGrid,
        ).layout,
        CollectionShelfLayout.compactGrid,
      );
    },
  );

  test('compact grid column count scales with width', () {
    expect(collectionCompactGridColumnCount(400), 2);
    expect(collectionCompactGridColumnCount(600), 3);
    expect(collectionCompactGridColumnCount(800), 4);
    expect(collectionCompactGridColumnCount(1000), 5);
  });
}
