import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/collection/presentation/collection_shelf_card_content.dart';
import 'package:blindbox_app/features/collection/widgets/collection_series_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/collection_fixtures.dart';

ThemeData _shotTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFFA892CC),
    brightness: Brightness.light,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: const Color(0xFFF3EEE6),
  );
}

void main() {
  testWidgets('after Collection Series card spacing golden', (tester) async {
    final series = testShelfSeries(
      id: 'shot',
      name: 'Exciting Macaron',
      brand: 'POP MART',
      ipName: 'THE MONSTERS',
      figures: [
        for (var i = 0; i < 12; i++)
          ShelfFigure(
            id: 'f$i',
            seriesId: 'shot',
            name: 'Fig $i',
            rarity: 'Regular',
            isSecret: false,
          ),
      ],
    );
    final states = {
      for (final f in series.figures.take(3))
        f.id: TrackedFigure(figureId: f.id, state: FigureCollectionState.owned),
    };

    // Card content grew past 700px tall on Linux (1.8px overflow); keep headroom
    // so the golden captures the full card without a layout exception.
    await tester.binding.setSurfaceSize(const Size(400, 760));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: _shotTheme(),
        home: Scaffold(
          backgroundColor: const Color(0xFFF3EEE6),
          body: Center(
            child: RepaintBoundary(
              key: const Key('series_card_spacing_after'),
              child: CollectionSeriesCard(
                series: series,
                progress: progressForSeries(series, states),
                figureStates: states,
                cardContent: const CollectionShelfCardContentSelection([
                  CollectionShelfCardContentField.brand,
                ]),
                onTap: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    await expectLater(
      find.byKey(const Key('series_card_spacing_after')),
      matchesGoldenFile(
        'goldens/collection_series_card_spacing/after.png',
      ),
    );
  });
}
