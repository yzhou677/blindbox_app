import 'package:blindbox_app/core/theme/app_theme.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/collection/presentation/collection_card_tokens.dart';
import 'package:blindbox_app/features/collection/widgets/collection_browse_card.dart';
import 'package:blindbox_app/features/collection/widgets/collection_series_card.dart';
import 'package:blindbox_app/features/collection/widgets/collection_wishlist_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final expectedSeriesHeight = CollectionSeriesCard.railExtentFor(
    CollectionSeriesCardDensity.standard,
    metaLineCount: 1,
  );

  final expectedFigureHeight = CollectionCardTokens.wishlistFigureHeight();

  List<FlutterErrorDetails> captureOverflows() {
    final errors = <FlutterErrorDetails>[];
    final oldOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.toString().contains('overflowed')) {
        errors.add(details);
      }
      oldOnError?.call(details);
    };
    addTearDown(() => FlutterError.onError = oldOnError);
    return errors;
  }

  group('wishlistFigureHeight token', () {
    test('is an explicit packed sum, not Series maxPacked + magic', () {
      final scale = TextScaler.noScaling.scale(1);
      final expected =
          CollectionCardTokens.padding.vertical +
          CollectionCardTokens.coverExtent +
          CollectionCardTokens.imageToTitleGap +
          CollectionCardTokens.wishlistFigureTitleLineExtent *
              CollectionCardTokens.wishlistFigureTitleMaxLines *
              scale +
          CollectionCardTokens.titleToMetaGap +
          CollectionCardTokens.wishlistFigureBodyLineExtent *
              CollectionCardTokens.wishlistFigureSeriesMaxLines *
              scale +
          CollectionCardTokens.metaToProgressGap +
          CollectionCardTokens.wishlistFigureBodyLineExtent *
              CollectionCardTokens.wishlistFigureBrandMaxLines *
              scale +
          CollectionCardTokens.wishlistFigurePackSlack;

      expect(CollectionCardTokens.wishlistFigureHeight(), expected);
      // Must not be derived as maxPacked + 12 + extraSubtitle (removed one-offs).
      expect(
        CollectionCardTokens.wishlistFigureHeight(),
        isNot(
          CollectionCardTokens.maxPackedMinRailHeight +
              12 +
              18,
        ),
      );
    });

    test('grows with text scale', () {
      final base = CollectionCardTokens.wishlistFigureHeight();
      final large = CollectionCardTokens.wishlistFigureHeight(
        const TextScaler.linear(1.35),
      );
      expect(large, greaterThan(base));
    });
  });

  group('Wishlist Series Grid sizing', () {
    Future<void> pumpSeries(
      WidgetTester tester, {
      required List<WishlistedCatalogSeries> series,
      double width = 390,
      double textScale = 1.0,
    }) async {
      await tester.binding.setSurfaceSize(Size(width, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData(
            size: Size(width, 1200),
            textScaler: TextScaler.linear(textScale),
          ),
          child: MaterialApp(
            theme: AppTheme.light(),
            home: Scaffold(
              body: SingleChildScrollView(
                child: CollectionWishlistPage(
                  snapshot: CollectionSnapshot(
                    shelfSeries: const [],
                    figureStates: const {},
                    seriesWishlist: series,
                  ),
                  searchQuery: '',
                  onRemoveSeries: (_) {},
                  onRemoveFigure: (_) {},
                  onOpenSeries: (_) {},
                  onOpenFigure: (_) {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    WishlistedCatalogSeries seriesItem({
      required String id,
      required String name,
      String brand = 'TOP TOY',
      String ipName = 'Heymi',
    }) {
      return WishlistedCatalogSeries(
        catalogSeriesId: id,
        name: name,
        brand: brand,
        ipName: ipName,
        imageKey: id,
        addedAtMicros: 1,
      );
    }

    Finder inSeries(Finder m) => find.descendant(
      of: find.byKey(const Key('wishlist_series_grid')),
      matching: m,
    );

    testWidgets('matches Collection Grid series height and packs footer', (
      tester,
    ) async {
      final overflows = captureOverflows();
      await pumpSeries(
        tester,
        series: [
          seriesItem(id: 's', name: 'Heymi', brand: 'TOP TOY', ipName: 'IP'),
        ],
      );

      final card = tester.widget<CollectionBrowseCard>(
        inSeries(find.byType(CollectionBrowseCard)),
      );
      expect(card.height, expectedSeriesHeight);
      expect(card.expandBeforeFooter, isFalse);
      expect(card.subtitleMaxLines, 1);
      expect(card.reserveTwoTitleLines, isFalse);
      expect(card.height, isNot(expectedFigureHeight));
      expect(overflows, isEmpty);
    });

    testWidgets('long title does not overflow; equal heights in Series grid', (
      tester,
    ) async {
      final overflows = captureOverflows();
      await pumpSeries(
        tester,
        width: 360,
        series: [
          seriesItem(id: 'a', name: 'Short'),
          seriesItem(
            id: 'b',
            name: 'An Extremely Long Wishlist Series Title That Needs Two Lines',
            brand: 'A Very Long Brand Name That Ellipsizes',
            ipName: 'Long IP Name That Ellipsizes On One Line',
          ),
        ],
      );

      final cards = inSeries(find.byType(CollectionBrowseCard));
      expect(tester.getSize(cards.at(0)).height, expectedSeriesHeight);
      expect(tester.getSize(cards.at(1)).height, expectedSeriesHeight);
      expect(overflows, isEmpty);
      expect(tester.takeException(), isNull);
    });

    testWidgets('missing IP or brand does not overflow', (tester) async {
      final overflows = captureOverflows();
      await pumpSeries(
        tester,
        series: [
          seriesItem(id: 'no-ip', name: 'Series', brand: 'POP MART', ipName: ''),
          seriesItem(id: 'no-brand', name: 'Series B', brand: '', ipName: 'IP'),
        ],
      );
      expect(overflows, isEmpty);
      expect(tester.takeException(), isNull);
    });
  });

  group('Wishlist Figure Grid sizing', () {
    ShelfSeries parent({
      String name = 'Parent Series With A Long Display Name',
      String brand = 'POP MART',
    }) {
      return ShelfSeries(
        id: 'parent',
        name: name,
        brand: brand,
        ipName: 'IP',
        figures: const [
          ShelfFigure(
            id: 'fig-a',
            seriesId: 'parent',
            name: 'DIMOO as Alien (Special Ver.)',
            rarity: 'Regular',
            isSecret: false,
            imageKey: 'fig-a',
          ),
          ShelfFigure(
            id: 'fig-b',
            seriesId: 'parent',
            name: 'Short Fig',
            rarity: 'Regular',
            isSecret: false,
            imageKey: 'fig-b',
          ),
        ],
        shelfAccent: const Color(0xFFE8DEF5),
      );
    }

    Future<void> pumpFigures(
      WidgetTester tester, {
      required ShelfSeries series,
      Map<String, TrackedFigure> states = const {
        'fig-a': TrackedFigure(
          figureId: 'fig-a',
          state: FigureCollectionState.wishlist,
          updatedAtMicros: 1,
        ),
        'fig-b': TrackedFigure(
          figureId: 'fig-b',
          state: FigureCollectionState.wishlist,
          updatedAtMicros: 2,
        ),
      },
      double width = 390,
      double textScale = 1.0,
    }) async {
      await tester.binding.setSurfaceSize(Size(width, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData(
            size: Size(width, 1400),
            textScaler: TextScaler.linear(textScale),
          ),
          child: MaterialApp(
            theme: AppTheme.light(),
            home: Scaffold(
              body: SingleChildScrollView(
                child: CollectionWishlistPage(
                  snapshot: CollectionSnapshot(
                    shelfSeries: [series],
                    figureStates: states,
                  ),
                  searchQuery: '',
                  onRemoveSeries: (_) {},
                  onRemoveFigure: (_) {},
                  onOpenSeries: (_) {},
                  onOpenFigure: (_) {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    Finder inFigures(Finder m) => find.descendant(
      of: find.byKey(const Key('wishlist_figures_grid')),
      matching: m,
    );

    testWidgets('uses packed figure height without Spacer blank band', (
      tester,
    ) async {
      final overflows = captureOverflows();
      await pumpFigures(tester, series: parent());

      final card = tester.widget<CollectionBrowseCard>(
        inFigures(find.byType(CollectionBrowseCard)).first,
      );
      expect(card.height, expectedFigureHeight);
      expect(card.expandBeforeFooter, isFalse);
      expect(card.reserveTwoTitleLines, isTrue);
      expect(
        card.subtitleMaxLines,
        CollectionCardTokens.wishlistFigureSeriesMaxLines,
      );
      expect(card.titleMaxLines, CollectionCardTokens.wishlistFigureTitleMaxLines);

      // Brand sits just below series name — not pinned to the card bottom.
      final seriesName = inFigures(
        find.text('Parent Series With A Long Display Name'),
      ).first;
      final brand = inFigures(find.text('POP MART')).first;
      final gap =
          tester.getTopLeft(brand).dy - tester.getBottomLeft(seriesName).dy;
      expect(gap, lessThan(CollectionCardTokens.metaToProgressGap + 8));
      expect(gap, greaterThan(0));

      expect(overflows, isEmpty);
    });

    testWidgets('short and long figure titles stay equal-height without overflow', (
      tester,
    ) async {
      final overflows = captureOverflows();
      await pumpFigures(
        tester,
        width: 360,
        series: parent(
          name: 'An Extremely Long Parent Series Name For Two Line Coverage',
        ),
      );

      final cards = inFigures(find.byType(CollectionBrowseCard));
      expect(cards, findsNWidgets(2));
      expect(tester.getSize(cards.at(0)).height, expectedFigureHeight);
      expect(tester.getSize(cards.at(1)).height, expectedFigureHeight);

      final longSeries = tester.widget<Text>(
        inFigures(
          find.textContaining('Extremely Long Parent Series Name'),
        ).first,
      );
      expect(longSeries.maxLines, 2);
      expect(longSeries.overflow, TextOverflow.ellipsis);
      expect(overflows, isEmpty);
      expect(tester.takeException(), isNull);
    });

    testWidgets('missing brand still packs without overflow', (tester) async {
      final overflows = captureOverflows();
      await pumpFigures(tester, series: parent(brand: ''));
      expect(overflows, isEmpty);
      expect(tester.takeException(), isNull);
    });

    testWidgets('large text scale grows figure height without overflow', (
      tester,
    ) async {
      final overflows = captureOverflows();
      final largeHeight = CollectionCardTokens.wishlistFigureHeight(
        const TextScaler.linear(1.35),
      );
      await pumpFigures(tester, series: parent(), textScale: 1.35);

      final card = tester.widget<CollectionBrowseCard>(
        inFigures(find.byType(CollectionBrowseCard)).first,
      );
      expect(card.height, largeHeight);
      expect(largeHeight, greaterThan(expectedFigureHeight));
      expect(overflows, isEmpty);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Series and Figure grids keep separate family heights', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(390, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: CollectionWishlistPage(
                snapshot: CollectionSnapshot(
                  shelfSeries: [parent()],
                  figureStates: const {
                    'fig-a': TrackedFigure(
                      figureId: 'fig-a',
                      state: FigureCollectionState.wishlist,
                      updatedAtMicros: 1,
                    ),
                  },
                  seriesWishlist: const [
                    WishlistedCatalogSeries(
                      catalogSeriesId: 'saved',
                      name: 'Wishlist Series',
                      brand: 'TOP TOY',
                      ipName: 'Heymi',
                      imageKey: 'saved',
                      addedAtMicros: 1,
                    ),
                  ],
                ),
                searchQuery: '',
                onRemoveSeries: (_) {},
                onRemoveFigure: (_) {},
                onOpenSeries: (_) {},
                onOpenFigure: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final seriesH = tester
          .getSize(
            find.descendant(
              of: find.byKey(const Key('wishlist_series_grid')),
              matching: find.byType(CollectionBrowseCard),
            ),
          )
          .height;
      final figureH = tester
          .getSize(
            find.descendant(
              of: find.byKey(const Key('wishlist_figures_grid')),
              matching: find.byType(CollectionBrowseCard),
            ),
          )
          .height;
      expect(seriesH, expectedSeriesHeight);
      expect(figureH, expectedFigureHeight);
      expect(seriesH, isNot(figureH));
    });
  });
}
