import 'package:blindbox_app/core/theme/app_theme.dart';
import 'package:blindbox_app/features/collection/application/collection_notifier.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/collection/insights/widgets/collector_type_top_series_rail.dart';
import 'package:blindbox_app/features/collection/widgets/collection_series_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/collection_fixtures.dart';

final class _TopSeriesRailNotifier extends CollectionNotifier {
  _TopSeriesRailNotifier(this._snap);

  final CollectionSnapshot _snap;

  @override
  CollectionSnapshot build() => _snap;
}

void main() {
  testWidgets('top series rail shows compact cards in name order', (
    tester,
  ) async {
    final hirono = testShelfSeries(
      id: 's1',
      name: 'The Other One',
      ipName: 'Hirono',
      figures: [
        for (var i = 0; i < 4; i++)
          ShelfFigure(
            id: 'h$i',
            seriesId: 's1',
            name: 'H $i',
            rarity: 'Regular',
            isSecret: false,
          ),
      ],
    );
    final dimoo = testShelfSeries(
      id: 's2',
      name: 'Dimoo World',
      ipName: 'Dimoo',
      figures: [
        for (var i = 0; i < 3; i++)
          ShelfFigure(
            id: 'd$i',
            seriesId: 's2',
            name: 'D $i',
            rarity: 'Regular',
            isSecret: false,
          ),
      ],
    );
    final snap = CollectionSnapshot(
      shelfSeries: [hirono, dimoo],
      figureStates: {
        for (final f in hirono.figures.take(2))
          f.id: TrackedFigure(
            figureId: f.id,
            state: FigureCollectionState.owned,
          ),
        for (final f in dimoo.figures.take(1))
          f.id: TrackedFigure(
            figureId: f.id,
            state: FigureCollectionState.owned,
          ),
      },
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          collectionNotifierProvider.overrideWith(
            () => _TopSeriesRailNotifier(snap),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(
            body: CollectorTypeTopSeriesRail(
              seriesNames: ['Dimoo World', 'The Other One', 'Missing'],
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const Key('collector_type_top_series_rail')), findsOneWidget);
    expect(find.byType(CollectionSeriesCard), findsNWidgets(2));
    expect(find.text('Dimoo World'), findsOneWidget);
    expect(find.text('The Other One'), findsOneWidget);
    expect(find.text('1'), findsNothing);
    expect(find.text('2'), findsNothing);

    // Name order from stats preserved (Dimoo first).
    final cards = tester.widgetList<CollectionSeriesCard>(
      find.byType(CollectionSeriesCard),
    );
    expect(cards.first.series.name, 'Dimoo World');
    expect(cards.first.density, CollectionSeriesCardDensity.compact);
  });
}
