import 'package:blindbox_app/core/theme/app_theme.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/collection/widgets/series_shelf_cards.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/collection_fixtures.dart';

void main() {
  testWidgets('shelf card does not display private series notes', (
    tester,
  ) async {
    final series = testShelfSeries(
      id: 'private_note',
      name: 'Private Notes Series',
      notes: 'Only I need to see this.',
      figures: const [
        ShelfFigure(
          id: 'private_note_f0',
          seriesId: 'private_note',
          name: 'Only',
          rarity: 'Regular',
          isSecret: false,
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: SeriesShelfCard(
            series: series,
            progress: progressForSeries(series, const {}),
            figureStates: const {},
            onOpen: () {},
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Private Notes Series'), findsOneWidget);
    expect(find.text('Only I need to see this.'), findsNothing);
  });
}
