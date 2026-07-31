import 'package:blindbox_app/core/theme/app_spacing.dart';
import 'package:blindbox_app/core/theme/app_theme.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/collection/presentation/collection_series_thumbnail.dart';
import 'package:blindbox_app/features/collection/presentation/collection_shelf_card_content.dart';
import 'package:blindbox_app/features/collection/widgets/collection_series_card_content_meta.dart';
import 'package:blindbox_app/features/collection/widgets/collection_shelf_series_list_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'helpers/collection_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  ShelfSeries series({
    String name = 'Alpha Series',
    String brand = 'POP MART',
    String ipName = 'Hirono',
  }) {
    return testShelfSeries(
      id: 'a',
      name: name,
      brand: brand,
      ipName: ipName,
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
    );
  }

  Future<void> pumpTile(
    WidgetTester tester, {
    required ShelfSeries row,
    Map<String, TrackedFigure> states = const {},
    CollectionShelfCardContentSelection cardContent =
        CollectionShelfCardContentSelection.empty,
    double width = 390,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
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
                onTap: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets(
    'List card renders artwork, title, meta, progress bar, count, chevron',
    (tester) async {
      final row = series();
      final states = {
        'a1': const TrackedFigure(
          figureId: 'a1',
          state: FigureCollectionState.owned,
          ownedQuantity: 2,
        ),
      };
      await pumpTile(
        tester,
        row: row,
        states: states,
        cardContent: const CollectionShelfCardContentSelection([
          CollectionShelfCardContentField.brand,
        ]),
      );

      expect(find.byType(CollectionSeriesThumbnail), findsOneWidget);
      expect(find.text('Alpha Series'), findsOneWidget);
      expect(find.byType(CollectionSeriesCardContentMeta), findsOneWidget);
      expect(find.textContaining('POP MART'), findsOneWidget);
      expect(
        find.byKey(const Key('collection_series_list_progress_bar')),
        findsOneWidget,
      );
      expect(find.textContaining('/'), findsOneWidget);
      expect(find.byIcon(Symbols.chevron_right_rounded), findsOneWidget);

      final tile = tester.getSize(
        find.byKey(const Key('collection_series_list_tile')),
      );
      expect(
        tile.height,
        closeTo(CollectionShelfSeriesListTile.minCardHeight, 1.0),
      );
      expect(CollectionShelfSeriesListTile.minCardHeight, 104);
      expect(CollectionShelfSeriesListTile.thumbExtent, 80);
      expect(
        CollectionShelfSeriesListTile.contentPadding.vertical,
        AppSpacing.md * 2,
      );
    },
  );

  testWidgets('zero-progress List cards still render the progress bar', (
    tester,
  ) async {
    final row = series();
    await pumpTile(tester, row: row, states: const {});

    final bar = tester.widget<LinearProgressIndicator>(
      find.byKey(const Key('collection_series_list_progress_bar')),
    );
    expect(bar.value, 0);
    expect(find.textContaining('0 /'), findsOneWidget);
  });

  testWidgets('missing metadata leaves no empty metadata row', (tester) async {
    final row = series(brand: '', ipName: '');
    await pumpTile(
      tester,
      row: row,
      cardContent: const CollectionShelfCardContentSelection([
        CollectionShelfCardContentField.brand,
        CollectionShelfCardContentField.ip,
      ]),
    );

    expect(find.byType(CollectionSeriesCardContentMeta), findsNothing);
    expect(find.byKey(const Key('collection_series_list_meta')), findsNothing);
    expect(
      find.byKey(const Key('collection_series_list_progress_bar')),
      findsOneWidget,
    );
  });

  testWidgets('long names and metadata ellipsize without overflow', (
    tester,
  ) async {
    final errors = <FlutterErrorDetails>[];
    final oldOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.toString().contains('overflowed')) {
        errors.add(details);
      }
      oldOnError?.call(details);
    };
    addTearDown(() => FlutterError.onError = oldOnError);

    final row = series(
      name: 'A Very Long Series Name That Should Ellipsize Gracefully On Card',
      brand: 'An Extremely Long Brand Name For Truncation Coverage',
    );
    await pumpTile(
      tester,
      row: row,
      width: 320,
      states: {
        'a1': const TrackedFigure(
          figureId: 'a1',
          state: FigureCollectionState.owned,
        ),
      },
      cardContent: const CollectionShelfCardContentSelection([
        CollectionShelfCardContentField.brand,
      ]),
    );

    expect(errors, isEmpty);
    expect(find.textContaining('A Very Long Series Name'), findsOneWidget);
    expect(find.byType(CollectionSeriesCardContentMeta), findsOneWidget);

    final title = tester.widget<Text>(
      find.textContaining('A Very Long Series Name'),
    );
    expect(title.maxLines, 1);
    expect(title.overflow, TextOverflow.ellipsis);
  });

  test('List spacing tokens match the spacious card recipe', () {
    expect(CollectionShelfSeriesListTile.thumbExtent, 80);
    expect(CollectionShelfSeriesListTile.minCardHeight, 104);
    expect(CollectionShelfSeriesListTile.chevronSlotWidth, greaterThan(0));
    expect(CollectionShelfSeriesListTile.titleToMetaGap, 6);
    expect(CollectionShelfSeriesListTile.metaToProgressGap, AppSpacing.sm);
    expect(CollectionShelfSeriesListTile.progressToCountGap, 6);
    expect(CollectionShelfSeriesListTile.artworkToTextGap, AppSpacing.md);
  });
}
