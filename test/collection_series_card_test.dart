import 'package:blindbox_app/core/theme/app_theme.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/collection/presentation/collection_card_tokens.dart';
import 'package:blindbox_app/features/collection/presentation/collection_vocabulary.dart';
import 'package:blindbox_app/features/collection/widgets/collection_series_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/collection_fixtures.dart';

void main() {
  testWidgets('in-progress card shows progress bar and count', (tester) async {
    final series = testShelfSeries(
      id: 's1',
      name: 'Dimoo World',
      ipName: 'Dimoo',
      figures: [
        for (var i = 0; i < 4; i++)
          ShelfFigure(
            id: 'f$i',
            seriesId: 's1',
            name: 'Fig $i',
            rarity: 'Regular',
            isSecret: false,
          ),
      ],
    );
    final states = {
      for (final f in series.figures.take(2))
        f.id: TrackedFigure(
          figureId: f.id,
          state: FigureCollectionState.owned,
        ),
    };

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: CollectionSeriesCard(
            series: series,
            progress: progressForSeries(series, states),
            figureStates: states,
            onTap: () {},
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Dimoo World'), findsOneWidget);
    expect(find.text('Dimoo'), findsOneWidget);
    expect(find.text('2 / 4'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.text(CollectionVocabulary.seriesCompleteBadge), findsNothing);
    expect(find.byIcon(Icons.delete_outline_rounded), findsNothing);
  });

  testWidgets('completed card reuses shell with Complete state', (tester) async {
    final series = testShelfSeries(
      id: 's2',
      name: 'Hirono Done',
      ipName: 'Hirono',
      figures: [
        ShelfFigure(
          id: 'a',
          seriesId: 's2',
          name: 'A',
          rarity: 'Regular',
          isSecret: false,
        ),
        ShelfFigure(
          id: 'b',
          seriesId: 's2',
          name: 'B',
          rarity: 'Regular',
          isSecret: false,
        ),
      ],
    );
    final states = {
      for (final f in series.figures)
        f.id: TrackedFigure(
          figureId: f.id,
          state: FigureCollectionState.owned,
        ),
    };

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: CollectionSeriesCard(
            series: series,
            progress: progressForSeries(series, states),
            figureStates: states,
            onTap: () {},
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Hirono Done'), findsOneWidget);
    expect(find.text(CollectionVocabulary.seriesCompleteBadge), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
  });

  testWidgets('compact density uses mini footprint without delete chrome', (
    tester,
  ) async {
    final series = testShelfSeries(
      id: 's3',
      name: 'Mini Series',
      ipName: 'Hirono',
      figures: [
        for (var i = 0; i < 4; i++)
          ShelfFigure(
            id: 'm$i',
            seriesId: 's3',
            name: 'Fig $i',
            rarity: 'Regular',
            isSecret: false,
          ),
      ],
    );
    final states = {
      for (final f in series.figures.take(1))
        f.id: TrackedFigure(
          figureId: f.id,
          state: FigureCollectionState.owned,
        ),
    };

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: CollectionSeriesCard(
            series: series,
            progress: progressForSeries(series, states),
            figureStates: states,
            density: CollectionSeriesCardDensity.compact,
            onTap: () {},
          ),
        ),
      ),
    );
    await tester.pump();

    final card = tester.getSize(find.byKey(const Key('collection_series_card')));
    expect(card.width, CollectionCardTokens.compactWidth);
    expect(card.height, CollectionCardTokens.compactMinRailHeight);
    expect(find.text('Mini Series'), findsOneWidget);
    expect(find.text('Hirono'), findsOneWidget);
    expect(find.text('1 / 4'), findsOneWidget);
    expect(find.byIcon(Icons.delete_outline_rounded), findsNothing);
  });
}
