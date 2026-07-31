import 'package:blindbox_app/core/theme/app_theme.dart';
import 'package:blindbox_app/features/catalog/catalog_bundle.dart';
import 'package:blindbox_app/features/catalog/models/catalog_series.dart'
    as catalog;
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/collection/presentation/collection_shelf_card_content.dart';
import 'package:blindbox_app/features/collection/widgets/collection_series_card_content_meta.dart';
import 'package:blindbox_app/features/collection/widgets/collection_shelf_series_list_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/collection_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  ShelfSeries series({
    String name = 'Alpha Series',
    String brand = 'POP MART',
    String id = 'a',
    String? catalogTemplateId = 'catalog_a',
  }) {
    return testShelfSeries(
      id: id,
      name: name,
      brand: brand,
      ipName: 'Hirono',
      catalogTemplateId: catalogTemplateId,
      figures: [
        ShelfFigure(
          id: '${id}1',
          seriesId: id,
          name: 'A1',
          rarity: 'Regular',
          isSecret: false,
        ),
        ShelfFigure(
          id: '${id}2',
          seriesId: id,
          name: 'A2',
          rarity: 'Regular',
          isSecret: false,
        ),
      ],
    );
  }

  CatalogSeedBundle catalogWithRelease() {
    return CatalogSeedBundle(
      brands: const [],
      ips: const [],
      series: [
        catalog.CatalogSeries(
          id: 'catalog_a',
          brandId: 'pop_mart',
          ipId: 'hirono',
          displayName: 'Alpha Series',
          releaseDate: '2024-07-12',
          isBlindBox: true,
          imageKey: 'catalog_a',
        ),
      ],
      figures: const [],
    );
  }

  Future<void> pumpTile(
    WidgetTester tester, {
    required ShelfSeries row,
    Map<String, TrackedFigure> states = const {},
    CollectionShelfCardContentSelection cardContent =
        CollectionShelfCardContentSelection.empty,
    CatalogSeedBundle? catalog,
    double width = 390,
    double textScale = 1.0,
  }) async {
    await tester.binding.setSurfaceSize(Size(width, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(
          size: Size(width, 800),
          textScaler: TextScaler.linear(textScale),
        ),
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: width,
                child: CollectionShelfSeriesListTile(
                  series: row,
                  progress: progressForSeries(row, states),
                  figureStates: states,
                  cardContent: cardContent,
                  catalog: catalog,
                  onTap: () {},
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  List<FlutterErrorDetails> captureOverflows(WidgetTester tester) {
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

  bool textExceedsMaxLines(WidgetTester tester, Finder finder) {
    final render = tester.renderObject(finder);
    if (render is! RenderParagraph) return false;
    return render.didExceedMaxLines;
  }

  group('List card stacked metadata rows', () {
    testWidgets('any two Card Content fields stack on separate rows', (
      tester,
    ) async {
      final overflows = captureOverflows(tester);
      await pumpTile(
        tester,
        row: series(),
        cardContent: const CollectionShelfCardContentSelection([
          CollectionShelfCardContentField.brand,
          CollectionShelfCardContentField.ip,
        ]),
      );

      expect(find.text('POP MART'), findsOneWidget);
      expect(find.text('Hirono'), findsOneWidget);
      expect(
        find.byKey(const Key('collection_series_list_meta_line_0')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('collection_series_list_meta_line_1')),
        findsOneWidget,
      );
      // No middot-compressed single run.
      expect(find.textContaining(' · '), findsNothing);

      final firstY = tester
          .getTopLeft(find.byKey(const Key('collection_series_list_meta_line_0')))
          .dy;
      final secondY = tester
          .getTopLeft(find.byKey(const Key('collection_series_list_meta_line_1')))
          .dy;
      expect(secondY, greaterThan(firstY));
      expect(overflows, isEmpty);
    });

    testWidgets('release date and duplicate each occupy their own row', (
      tester,
    ) async {
      final overflows = captureOverflows(tester);
      await pumpTile(
        tester,
        row: series(),
        states: {
          'a1': const TrackedFigure(
            figureId: 'a1',
            state: FigureCollectionState.owned,
            ownedQuantity: 2,
          ),
        },
        catalog: catalogWithRelease(),
        cardContent: const CollectionShelfCardContentSelection([
          CollectionShelfCardContentField.usReleaseDate,
          CollectionShelfCardContentField.duplicateCount,
        ]),
      );

      expect(find.text('1 duplicate'), findsOneWidget);
      expect(find.textContaining('U.S.'), findsOneWidget);
      expect(
        find.byKey(const Key('collection_series_list_meta_line_0')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('collection_series_list_meta_line_1')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('collection_series_list_meta_duplicate')),
        findsOneWidget,
      );
      expect(textExceedsMaxLines(tester, find.text('1 duplicate')), isFalse);
      expect(overflows, isEmpty);
    });

    testWidgets('multiple duplicates show full plural copy', (tester) async {
      final overflows = captureOverflows(tester);
      await pumpTile(
        tester,
        row: series(),
        states: {
          'a1': const TrackedFigure(
            figureId: 'a1',
            state: FigureCollectionState.owned,
            ownedQuantity: 3,
          ),
        },
        cardContent: const CollectionShelfCardContentSelection([
          CollectionShelfCardContentField.brand,
          CollectionShelfCardContentField.duplicateCount,
        ]),
      );

      expect(find.text('2 duplicates'), findsOneWidget);
      expect(textExceedsMaxLines(tester, find.text('2 duplicates')), isFalse);
      expect(overflows, isEmpty);
    });

    testWidgets('single meta field leaves no empty second row', (tester) async {
      await pumpTile(
        tester,
        row: series(),
        states: {
          'a1': const TrackedFigure(
            figureId: 'a1',
            state: FigureCollectionState.owned,
            ownedQuantity: 1,
          ),
        },
        catalog: catalogWithRelease(),
        cardContent: const CollectionShelfCardContentSelection([
          CollectionShelfCardContentField.usReleaseDate,
          CollectionShelfCardContentField.duplicateCount,
        ]),
      );

      expect(find.textContaining('duplicate'), findsNothing);
      expect(
        find.byKey(const Key('collection_series_list_meta_line_0')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('collection_series_list_meta_line_1')),
        findsNothing,
      );

      final tile = tester.getSize(
        find.byKey(const Key('collection_series_list_tile')),
      );
      expect(
        tile.height,
        closeTo(CollectionShelfSeriesListTile.minCardHeight, 1.0),
      );
    });

    testWidgets('long series title ellipsizes; duplicate copy stays complete', (
      tester,
    ) async {
      final overflows = captureOverflows(tester);
      await pumpTile(
        tester,
        row: series(
          name:
              'An Extremely Long Series Title That Must Ellipsize On The List Card',
        ),
        width: 320,
        states: {
          'a1': const TrackedFigure(
            figureId: 'a1',
            state: FigureCollectionState.owned,
            ownedQuantity: 2,
          ),
        },
        cardContent: const CollectionShelfCardContentSelection([
          CollectionShelfCardContentField.brand,
          CollectionShelfCardContentField.duplicateCount,
        ]),
      );

      final title = tester.widget<Text>(
        find.textContaining('An Extremely Long Series Title'),
      );
      expect(title.maxLines, 1);
      expect(title.overflow, TextOverflow.ellipsis);
      expect(find.text('1 duplicate'), findsOneWidget);
      expect(textExceedsMaxLines(tester, find.text('1 duplicate')), isFalse);
      expect(overflows, isEmpty);
    });

    testWidgets('narrow supported width keeps stacked copy intact', (
      tester,
    ) async {
      final overflows = captureOverflows(tester);
      await pumpTile(
        tester,
        row: series(),
        width: 320,
        states: {
          'a1': const TrackedFigure(
            figureId: 'a1',
            state: FigureCollectionState.owned,
            ownedQuantity: 4,
          ),
        },
        catalog: catalogWithRelease(),
        cardContent: const CollectionShelfCardContentSelection([
          CollectionShelfCardContentField.usReleaseDate,
          CollectionShelfCardContentField.duplicateCount,
        ]),
      );

      expect(find.text('3 duplicates'), findsOneWidget);
      expect(textExceedsMaxLines(tester, find.text('3 duplicates')), isFalse);
      expect(
        find.byKey(const Key('collection_series_list_chevron_slot')),
        findsOneWidget,
      );
      expect(overflows, isEmpty);
    });

    testWidgets(
      'large text scale grows card; duplicate may wrap up to two lines',
      (tester) async {
        final overflows = captureOverflows(tester);
        await pumpTile(
          tester,
          row: series(),
          width: 320,
          textScale: 1.6,
          states: {
            'a1': const TrackedFigure(
              figureId: 'a1',
              state: FigureCollectionState.owned,
              ownedQuantity: 2,
            ),
          },
          cardContent: const CollectionShelfCardContentSelection([
            CollectionShelfCardContentField.brand,
            CollectionShelfCardContentField.duplicateCount,
          ]),
        );

        expect(find.text('1 duplicate'), findsOneWidget);
        final dupText = tester.widget<Text>(find.text('1 duplicate'));
        expect(dupText.maxLines, 2);
        expect(dupText.softWrap, isTrue);

        final tile = tester.getSize(
          find.byKey(const Key('collection_series_list_tile')),
        );
        expect(
          tile.height,
          greaterThan(CollectionShelfSeriesListTile.minCardHeight),
        );
        expect(overflows, isEmpty);
      },
    );

    testWidgets('long localized duplicate copy stacks below primary field', (
      tester,
    ) async {
      final overflows = captureOverflows(tester);
      await tester.binding.setSurfaceSize(const Size(300, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      const longCopy =
          '1 duplicate copy reserved for trade partners and shelf notes';
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(
            size: Size(300, 800),
            textScaler: TextScaler.linear(1.3),
          ),
          child: MaterialApp(
            theme: AppTheme.light(),
            home: Scaffold(
              body: Padding(
                padding: const EdgeInsets.all(12),
                child: CollectionSeriesCardContentMeta(
                  horizontal: true,
                  lines: const [
                    CollectionShelfCardContentLine(
                      field: CollectionShelfCardContentField.usReleaseDate,
                      text: 'U.S. Jul 12, 2024',
                      icon: Icons.calendar_month,
                    ),
                    CollectionShelfCardContentLine(
                      field: CollectionShelfCardContentField.duplicateCount,
                      text: longCopy,
                      icon: Icons.filter_none,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text(longCopy), findsOneWidget);
      final dupText = tester.widget<Text>(find.text(longCopy));
      expect(dupText.maxLines, 2);
      expect(dupText.softWrap, isTrue);
      expect(
        find.byKey(const Key('collection_series_list_meta_line_0')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('collection_series_list_meta_line_1')),
        findsOneWidget,
      );
      expect(overflows, isEmpty);
    });
  });
}
