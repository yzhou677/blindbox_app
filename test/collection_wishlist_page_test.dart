import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/collection/presentation/collection_wishlist_browse.dart';
import 'package:blindbox_app/features/collection/widgets/collection_browse_card.dart';
import 'package:blindbox_app/features/collection/widgets/collection_wishlist_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('remove icon removes only and does not open Series card', (
    tester,
  ) async {
    var removes = 0;
    var opens = 0;
    await _pumpWishlist(
      tester,
      snapshot: _seriesOnlySnapshot(),
      onRemoveSeries: (_) => removes++,
      onOpenSeries: (_) => opens++,
    );

    await tester.tap(find.byTooltip('Remove Series from Wishlist'));
    await tester.pump();

    expect(removes, 1);
    expect(opens, 0);
  });

  testWidgets('remove touch target is accessible while visually compact', (
    tester,
  ) async {
    await _pumpWishlist(tester, snapshot: _seriesOnlySnapshot());

    final target = find.byKey(
      const ValueKey('wishlist_remove_series_saved-series'),
    );

    expect(tester.getSize(target), const Size(44, 44));
    expect(find.byTooltip('Remove Series from Wishlist'), findsOneWidget);
  });

  testWidgets('Series and Figure cards use balanced two-column grids', (
    tester,
  ) async {
    await _pumpWishlist(tester, snapshot: _mixedSnapshot());

    expect(find.byKey(const Key('wishlist_series_grid')), findsOneWidget);
    expect(find.byKey(const Key('wishlist_figures_grid')), findsOneWidget);
    expect(find.text('Saved Series With A Long Calm Name'), findsOneWidget);
    expect(find.text('Molly'), findsOneWidget);
  });

  testWidgets(
    'Figure card prioritizes Figure name, parent Series, then Brand',
    (tester) async {
      await _pumpWishlist(tester, snapshot: _figureOnlySnapshot());

      expect(find.text('DIMOO as Alien (Special Ver.)'), findsOneWidget);
      expect(find.text('Parent Series'), findsOneWidget);
      expect(find.text('POP MART'), findsOneWidget);
    },
  );

  testWidgets('Figure card tap opens preview without removing item', (
    tester,
  ) async {
    var opens = 0;
    var removes = 0;
    await _pumpWishlist(
      tester,
      snapshot: _figureOnlySnapshot(),
      onOpenFigure: (_) => opens++,
      onRemoveFigure: (_) => removes++,
    );

    await tester.tap(find.text('DIMOO as Alien (Special Ver.)'));
    await tester.pump();

    expect(opens, 1);
    expect(removes, 0);
  });

  testWidgets('true empty copy avoids using Wishlist as a verb', (
    tester,
  ) async {
    await _pumpWishlist(tester, snapshot: CollectionSnapshot.emptyTest());

    expect(find.text('Your wishlist is empty.'), findsOneWidget);
    expect(
      find.text('Save catalog series to plan what to collect next.'),
      findsOneWidget,
    );
    expect(find.textContaining('Wishlist catalog series'), findsNothing);
  });

  testWidgets('empty sections are hidden when the Wishlist is not empty', (
    tester,
  ) async {
    await _pumpWishlist(tester, snapshot: _seriesOnlySnapshot());

    expect(find.text('Series (1)'), findsOneWidget);
    expect(find.text('Figures (0)'), findsNothing);
    expect(find.text('No wishlisted Figures yet.'), findsNothing);
  });

  testWidgets('search empty copy does not claim Wishlist is truly empty', (
    tester,
  ) async {
    await _pumpWishlist(
      tester,
      snapshot: _seriesOnlySnapshot(),
      searchQuery: 'no match',
    );

    expect(find.text('No Wishlist results found.'), findsOneWidget);
    expect(find.text('Your wishlist is empty.'), findsNothing);
    expect(find.text('Series (0)'), findsNothing);
    expect(find.text('Figures (0)'), findsNothing);
  });

  testWidgets('filtered empty sections are hidden while matches remain', (
    tester,
  ) async {
    await _pumpWishlist(
      tester,
      snapshot: _mixedSnapshot(),
      searchQuery: 'wish figure',
    );

    expect(find.text('Series (0)'), findsNothing);
    expect(find.text('No Series match your search.'), findsNothing);
    expect(find.text('Figures (1)'), findsOneWidget);
    expect(find.text('DIMOO as Alien (Special Ver.)'), findsOneWidget);
  });

  for (final textScale in <double>[1, 1.35]) {
    testWidgets(
      'Wishlist Figure cards fit long metadata and align at ${textScale}x text',
      (tester) async {
        await _pumpWishlist(
          tester,
          snapshot: _twoFigureSnapshot(),
          textScale: textScale,
        );

        expect(tester.takeException(), isNull);
        expect(find.text('DIMOO as Alien (Special Ver.)'), findsOneWidget);
        final cards = find.byType(CollectionBrowseCard);
        expect(cards, findsNWidgets(2));
        expect(
          find.descendant(
            of: cards,
            matching: find.text('Parent Series With A Long Display Name'),
          ),
          findsNWidgets(2),
        );
        expect(
          find.descendant(of: cards, matching: find.text('POP MART')),
          findsNWidgets(2),
        );

        final title = tester.widget<Text>(
          find.text('DIMOO as Alien (Special Ver.)'),
        );
        expect(title.maxLines, 2);
        expect(title.overflow, TextOverflow.ellipsis);

        expect(tester.getSize(cards.at(0)), tester.getSize(cards.at(1)));
        expect(
          tester.getTopLeft(cards.at(0)).dy,
          tester.getTopLeft(cards.at(1)).dy,
        );

        final firstRemove = find.byKey(
          const ValueKey('wishlist_remove_figure_wish-figure'),
        );
        expect(
          tester.getTopLeft(firstRemove).dy - tester.getTopLeft(cards.at(0)).dy,
          10,
        );
      },
    );
  }
}

Future<void> _pumpWishlist(
  WidgetTester tester, {
  required CollectionSnapshot snapshot,
  String searchQuery = '',
  ValueChanged<WishlistedCatalogSeries>? onRemoveSeries,
  ValueChanged<WishlistedFigureRow>? onRemoveFigure,
  ValueChanged<WishlistedCatalogSeries>? onOpenSeries,
  ValueChanged<WishlistedFigureRow>? onOpenFigure,
  double textScale = 1,
}) async {
  tester.view.physicalSize = const Size(430, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Scaffold(
        body: SingleChildScrollView(
          child: CollectionWishlistPage(
            snapshot: snapshot,
            searchQuery: searchQuery,
            onRemoveSeries: onRemoveSeries ?? (_) {},
            onRemoveFigure: onRemoveFigure ?? (_) {},
            onOpenSeries: onOpenSeries ?? (_) {},
            onOpenFigure: onOpenFigure ?? (_) {},
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

CollectionSnapshot _seriesOnlySnapshot() {
  return const CollectionSnapshot(
    shelfSeries: [],
    figureStates: {},
    seriesWishlist: [
      WishlistedCatalogSeries(
        catalogSeriesId: 'saved-series',
        name: 'Saved Series With A Long Calm Name',
        brand: 'POP MART',
        ipName: 'Molly',
        imageKey: 'saved-series',
        addedAtMicros: 10,
      ),
    ],
  );
}

CollectionSnapshot _figureOnlySnapshot() {
  final series = _parentSeries();
  return CollectionSnapshot(
    shelfSeries: [series],
    figureStates: const {
      'wish-figure': TrackedFigure(
        figureId: 'wish-figure',
        state: FigureCollectionState.wishlist,
        updatedAtMicros: 20,
      ),
    },
  );
}

CollectionSnapshot _mixedSnapshot() {
  final series = _parentSeries();
  return CollectionSnapshot(
    shelfSeries: [series],
    figureStates: const {
      'wish-figure': TrackedFigure(
        figureId: 'wish-figure',
        state: FigureCollectionState.wishlist,
        updatedAtMicros: 20,
      ),
    },
    seriesWishlist: const [
      WishlistedCatalogSeries(
        catalogSeriesId: 'saved-series',
        name: 'Saved Series With A Long Calm Name',
        brand: 'POP MART',
        ipName: 'Molly',
        imageKey: 'saved-series',
        addedAtMicros: 10,
      ),
    ],
  );
}

ShelfSeries _parentSeries() {
  return const ShelfSeries(
    id: 'parent-series',
    name: 'Parent Series With A Long Display Name',
    brand: 'POP MART',
    ipName: 'THE MONSTERS',
    figures: [
      ShelfFigure(
        id: 'wish-figure',
        seriesId: 'parent-series',
        name: 'DIMOO as Alien (Special Ver.)',
        imageKey: 'wish-figure',
        rarity: 'Regular',
        isSecret: false,
      ),
    ],
    shelfAccent: Color(0xFFE8DEF5),
  );
}

CollectionSnapshot _twoFigureSnapshot() {
  final first = _parentSeries();
  final second = ShelfSeries(
    id: first.id,
    name: first.name,
    brand: first.brand,
    ipName: first.ipName,
    figures: [
      ...first.figures,
      const ShelfFigure(
        id: 'neighbor-figure',
        seriesId: 'parent-series',
        name: 'DIMOO Neighbor Figure',
        imageKey: 'neighbor-figure',
        rarity: 'Regular',
        isSecret: false,
      ),
    ],
    shelfAccent: first.shelfAccent,
  );
  return CollectionSnapshot(
    shelfSeries: [second],
    figureStates: const {
      'wish-figure': TrackedFigure(
        figureId: 'wish-figure',
        state: FigureCollectionState.wishlist,
        updatedAtMicros: 20,
      ),
      'neighbor-figure': TrackedFigure(
        figureId: 'neighbor-figure',
        state: FigureCollectionState.wishlist,
        updatedAtMicros: 19,
      ),
    },
  );
}
