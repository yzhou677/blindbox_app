import 'package:blindbox_app/core/router/app_router.dart';
import 'package:blindbox_app/core/theme/app_theme.dart';
import 'package:blindbox_app/features/collection/application/collection_notifier.dart';
import 'package:blindbox_app/features/collection/collection_screen.dart';
import 'package:blindbox_app/features/collection/data/series_release_lookup.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/home/application/home_feed_provider.dart';
import 'package:blindbox_app/features/home/data/mock_latest_drops.dart';
import 'package:blindbox_app/features/official_feed/application/official_feed_providers.dart';
import 'package:blindbox_app/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

List<Override> _blindboxTestOverrides() => [
  homeFeedSnapshotProvider.overrideWith(
    (_) async => HomeFeedSnapshot(
      latest: mockSeriesReleases,
      trending: mockSeriesReleases.skip(1).take(4).toList(growable: false),
    ),
  ),
  officialFeedListProvider.overrideWith((_) async => const []),
  seriesReleaseLookupProvider.overrideWithValue(mockSeriesReleaseByDropId),
];

final class EmptyTestCollectionNotifier extends CollectionNotifier {
  @override
  CollectionSnapshot build() => CollectionSnapshot.emptyTest();
}

final class SeededTestCollectionNotifier extends CollectionNotifier {
  @override
  CollectionSnapshot build() {
    const seriesId = 'series_hirono_other_one';
    final series = ShelfSeries(
      id: seriesId,
      name: 'The Other One',
      brand: 'POP MART',
      ipName: 'Hirono',
      figures: const [
        ShelfFigure(
          id: 'fig_hirono_1',
          seriesId: seriesId,
          name: 'The Fox',
          rarity: 'Regular',
          isSecret: false,
        ),
        ShelfFigure(
          id: 'fig_hirono_2',
          seriesId: seriesId,
          name: 'The Bird',
          rarity: 'Regular',
          isSecret: false,
        ),
        ShelfFigure(
          id: 'fig_hirono_3',
          seriesId: seriesId,
          name: 'The Star',
          rarity: 'Regular',
          isSecret: false,
        ),
        ShelfFigure(
          id: 'fig_hirono_4',
          seriesId: seriesId,
          name: 'The Poem',
          rarity: 'Regular',
          isSecret: false,
        ),
        ShelfFigure(
          id: 'fig_hirono_5',
          seriesId: seriesId,
          name: 'The Secret',
          rarity: 'Regular',
          isSecret: false,
        ),
        ShelfFigure(
          id: 'fig_hirono_6',
          seriesId: seriesId,
          name: 'The Chase',
          rarity: 'Secret',
          isSecret: true,
        ),
      ],
      shelfAccent: const Color(0xFFF2E8DC),
      catalogTemplateId: 'series-hirono-other-one',
      taxonomyBrandId: 'pop_mart',
      taxonomyIpId: 'hirono',
    );

    return CollectionSnapshot(
      shelfSeries: [series],
      figureStates: const {
        'fig_hirono_1': TrackedFigure(
          figureId: 'fig_hirono_1',
          state: FigureCollectionState.owned,
        ),
        'fig_hirono_2': TrackedFigure(
          figureId: 'fig_hirono_2',
          state: FigureCollectionState.owned,
        ),
        'fig_hirono_3': TrackedFigure(
          figureId: 'fig_hirono_3',
          state: FigureCollectionState.owned,
        ),
        'fig_hirono_4': TrackedFigure(
          figureId: 'fig_hirono_4',
          state: FigureCollectionState.owned,
        ),
        'fig_hirono_5': TrackedFigure(
          figureId: 'fig_hirono_5',
          state: FigureCollectionState.owned,
        ),
        'fig_hirono_6': TrackedFigure(
          figureId: 'fig_hirono_6',
          state: FigureCollectionState.wishlist,
        ),
      },
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  setUp(() {
    // [appRouter] is a process-wide singleton; reset the shell tab between tests.
    appRouter.go('/collection');
  });

  testWidgets('App shell opens on Collection tab', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: _blindboxTestOverrides(),
        child: const BlindboxApp(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('My collection'), findsWidgets);
    expect(find.text('Collection'), findsWidgets);
  });

  testWidgets('Discover tab shows home feed', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: _blindboxTestOverrides(),
        child: const BlindboxApp(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    await tester.tap(find.byIcon(Icons.explore_outlined));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Discover'), findsWidgets);
    expect(find.text('Latest drops'), findsOneWidget);
    expect(find.text('Moon Mischief'), findsOneWidget);
    expect(find.text('Trending series'), findsOneWidget);
  });

  testWidgets('Collection tab shows series-first shelf and summary', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ..._blindboxTestOverrides(),
          collectionNotifierProvider.overrideWith(
            SeededTestCollectionNotifier.new,
          ),
        ],
        child: const BlindboxApp(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('My collection'), findsWidgets);
    expect(find.text('In collection'), findsOneWidget);
    expect(find.text('5'), findsOneWidget);
    expect(
      find.byKey(const Key('collection_header_add_series')),
      findsOneWidget,
    );
    expect(find.text('All'), findsOneWidget);

    // The shelf uses SliverList.builder (lazy) — scroll until the series card
    // enters the viewport before asserting its text is present.
    await tester.scrollUntilVisible(
      find.text('The Other One'),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('The Other One'), findsOneWidget);

    // Brand chips are built from shelf brands only (POP MART for this seed).
    await tester.scrollUntilVisible(
      find.text('POP MART'),
      80,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('POP MART'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.scrollUntilVisible(
      find.text('The Other One'),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('The Other One'), findsOneWidget);

    await tester.tap(find.text('All'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    // Scroll back to where 'The Other One' card is after filter reset.
    await tester.scrollUntilVisible(
      find.text('The Other One'),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('The Other One'), findsOneWidget);
  });

  testWidgets('Add series sheet dismisses when leaving Collection tab', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ..._blindboxTestOverrides(),
          collectionNotifierProvider.overrideWith(
            SeededTestCollectionNotifier.new,
          ),
        ],
        child: const BlindboxApp(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    await tester.tap(find.byKey(const Key('collection_header_add_series')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Add a series'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.explore_outlined));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Add a series'), findsNothing);

    await tester.tap(find.text('Collection'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Add a series'), findsNothing);
    expect(find.text('My collection'), findsWidgets);

    // Flush catalog background refresh timer started by Add sheet.
    await tester.pump(const Duration(seconds: 13));
  });

  testWidgets('Market tab shows search and browse filters', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: _blindboxTestOverrides(),
        child: const BlindboxApp(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    await tester.tap(find.text('Market'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('Chasers'), findsNothing);
    expect(find.text('Collectibles'), findsOneWidget);
    expect(find.text('Brand'), findsOneWidget);
    await tester.tap(find.text('POP MART'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('IP'), findsOneWidget);
    expect(find.text('THE MONSTERS'), findsWidgets);
  });

  testWidgets('Collection empty state is polished', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          collectionNotifierProvider.overrideWith(
            EmptyTestCollectionNotifier.new,
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const CollectionScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Empty shelf'), findsOneWidget);
    expect(find.text('Discover'), findsOneWidget);
  });
}
