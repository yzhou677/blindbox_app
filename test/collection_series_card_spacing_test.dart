import 'package:blindbox_app/core/theme/app_spacing.dart';
import 'package:blindbox_app/core/theme/app_theme.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/collection/presentation/collection_card_tokens.dart';
import 'package:blindbox_app/features/collection/presentation/collection_shelf_card_content.dart';
import 'package:blindbox_app/features/collection/widgets/collection_browse_card.dart';
import 'package:blindbox_app/features/collection/widgets/collection_series_card.dart';
import 'package:blindbox_app/features/collection/widgets/collection_series_card_content_meta.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/collection_fixtures.dart';

ShelfSeries _series({
  String name = 'Exciting Macaron',
  int figureCount = 12,
}) {
  return testShelfSeries(
    id: 'spacing',
    name: name,
    brand: 'POP MART',
    ipName: 'THE MONSTERS',
    figures: [
      for (var i = 0; i < figureCount; i++)
        ShelfFigure(
          id: 'f$i',
          seriesId: 'spacing',
          name: 'Fig $i',
          rarity: 'Regular',
          isSecret: false,
        ),
    ],
  );
}

Map<String, TrackedFigure> _owned(ShelfSeries series, int count) {
  return {
    for (final f in series.figures.take(count))
      f.id: TrackedFigure(figureId: f.id, state: FigureCollectionState.owned),
  };
}

Future<void> _pumpCard(
  WidgetTester tester, {
  required ShelfSeries series,
  required Map<String, TrackedFigure> states,
  CollectionShelfCardContentSelection cardContent =
      CollectionShelfCardContentSelection.empty,
  TextScaler textScaler = TextScaler.noScaling,
}) async {
  await tester.binding.setSurfaceSize(const Size(400, 800));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: textScaler),
        child: child!,
      ),
      home: Scaffold(
        body: Center(
          child: CollectionSeriesCard(
            series: series,
            progress: progressForSeries(series, states),
            figureStates: states,
            cardContent: cardContent,
            onTap: () {},
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('metadata rhythm uses deliberate fixed token gaps', (
    tester,
  ) async {
    final series = _series();
    final states = _owned(series, 3);
    await _pumpCard(
      tester,
      series: series,
      states: states,
      cardContent: const CollectionShelfCardContentSelection([
        CollectionShelfCardContentField.brand,
      ]),
    );

    expect(CollectionCardTokens.imageToTitleGap, AppSpacing.md);
    expect(CollectionCardTokens.titleToMetaGap, AppSpacing.lg);
    expect(CollectionCardTokens.metaToProgressGap, AppSpacing.lg);
    expect(CollectionCardTokens.progressToLabelGap, AppSpacing.sm);
    expect(CollectionCardTokens.padding.bottom, AppSpacing.lg);

    final titleBottom = tester.getBottomLeft(find.text('Exciting Macaron')).dy;
    final metaTop = tester
        .getTopLeft(find.byType(CollectionSeriesCardContentMeta))
        .dy;
    final metaBottom = tester
        .getBottomLeft(find.byType(CollectionSeriesCardContentMeta))
        .dy;
    final barTop = tester.getTopLeft(find.byType(LinearProgressIndicator)).dy;
    final barBottom = tester
        .getBottomLeft(find.byType(LinearProgressIndicator))
        .dy;
    final countTop = tester.getTopLeft(find.text('3 / 12')).dy;

    expect(metaTop - titleBottom, closeTo(AppSpacing.lg, 1.5));
    expect(barTop - metaBottom, closeTo(AppSpacing.lg, 1.5));
    expect(countTop - barBottom, closeTo(AppSpacing.sm, 1.5));
    // Still packed — no legacy mid-card Spacer band.
    expect(metaTop - titleBottom, lessThan(28));
  });

  testWidgets('title-to-meta gap is fixed token spacing, not spare height', (
    tester,
  ) async {
    final series = _series();
    final states = _owned(series, 3);
    await _pumpCard(
      tester,
      series: series,
      states: states,
      cardContent: const CollectionShelfCardContentSelection([
        CollectionShelfCardContentField.brand,
      ]),
    );

    final browse = tester.widget<CollectionBrowseCard>(
      find.byType(CollectionBrowseCard),
    );
    expect(browse.expandBeforeMeta, isFalse);
    expect(browse.expandBeforeFooter, isFalse);
    expect(browse.titleToMetaGap, AppSpacing.lg);
    expect(CollectionCardTokens.titleToMetaGap, AppSpacing.lg);

    final titleBottom = tester.getBottomLeft(find.text('Exciting Macaron')).dy;
    final metaTop = tester
        .getTopLeft(find.byType(CollectionSeriesCardContentMeta))
        .dy;
    expect(metaTop - titleBottom, closeTo(AppSpacing.lg, 1.5));

    // Must not consume a large mid-card band (legacy Spacer left ~30–50dp).
    expect(metaTop - titleBottom, lessThan(28));
  });

  testWidgets('row cards share equal packed height', (tester) async {
    final a = _series(name: 'Short');
    final b = _series(name: 'A much longer series title for two lines');
    final statesA = _owned(a, 2);
    final statesB = _owned(b, 5);

    await tester.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CollectionSeriesCard(
                series: a,
                progress: progressForSeries(a, statesA),
                figureStates: statesA,
                cardContent: const CollectionShelfCardContentSelection([
                  CollectionShelfCardContentField.brand,
                ]),
                onTap: () {},
              ),
              const SizedBox(width: 12),
              CollectionSeriesCard(
                series: b,
                progress: progressForSeries(b, statesB),
                figureStates: statesB,
                cardContent: const CollectionShelfCardContentSelection([
                  CollectionShelfCardContentField.brand,
                ]),
                onTap: () {},
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    final cards = tester.widgetList<CollectionBrowseCard>(
      find.byType(CollectionBrowseCard),
    );
    expect(cards, hasLength(2));
    expect(cards.first.height, cards.last.height);
    expect(
      cards.first.height,
      CollectionCardTokens.minRailHeightFor(
        MediaQuery.textScalerOf(
          tester.element(find.byType(CollectionBrowseCard).first),
        ),
        metaLineCount: 1,
      ),
    );
  });

  testWidgets('two-line series title does not overflow the card', (
    tester,
  ) async {
    final series = _series(
      name: 'Very Long Series Title That Needs Two Lines Here',
    );
    final states = _owned(series, 1);
    await _pumpCard(
      tester,
      series: series,
      states: states,
      cardContent: const CollectionShelfCardContentSelection([
        CollectionShelfCardContentField.brand,
      ]),
    );

    expect(tester.takeException(), isNull);
    final cardRect = tester.getRect(find.byType(CollectionBrowseCard));
    final titleRect = tester.getRect(
      find.text('Very Long Series Title That Needs Two Lines Here'),
    );
    expect(titleRect.bottom, lessThanOrEqualTo(cardRect.bottom));
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.textContaining('/'), findsOneWidget);
  });

  testWidgets('missing release-date meta leaves no reserved blank gap', (
    tester,
  ) async {
    final series = _series();
    final states = _owned(series, 3);
    await _pumpCard(
      tester,
      series: series,
      states: states,
      cardContent: CollectionShelfCardContentSelection.empty,
    );

    expect(find.byType(CollectionSeriesCardContentMeta), findsNothing);

    final titleBottom = tester.getBottomLeft(find.text('Exciting Macaron')).dy;
    final barTop = tester.getTopLeft(find.byType(LinearProgressIndicator)).dy;
    // Title → token footer gap only (no empty meta row, no Spacer band).
    expect(
      barTop - titleBottom,
      closeTo(CollectionCardTokens.metaToProgressGap, 2),
    );
  });

  testWidgets('progress bar and owned count stay visible and grouped', (
    tester,
  ) async {
    final series = _series();
    final states = _owned(series, 3);
    await _pumpCard(
      tester,
      series: series,
      states: states,
      cardContent: const CollectionShelfCardContentSelection([
        CollectionShelfCardContentField.brand,
      ]),
    );

    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.text('3 / 12'), findsOneWidget);

    final barBottom = tester
        .getBottomLeft(find.byType(LinearProgressIndicator))
        .dy;
    final countTop = tester.getTopLeft(find.text('3 / 12')).dy;
    expect(
      countTop - barBottom,
      closeTo(CollectionCardTokens.progressToLabelGap, 1.5),
    );
  });

  testWidgets('bottom padding below count is ~16dp without spare slack', (
    tester,
  ) async {
    final series = _series();
    final states = _owned(series, 3);
    await _pumpCard(tester, series: series, states: states);

    final cardBottom = tester
        .getBottomLeft(find.byType(CollectionBrowseCard))
        .dy;
    final countBottom = tester.getBottomLeft(find.text('3 / 12')).dy;
    final gap = cardBottom - countBottom;
    expect(gap, closeTo(CollectionCardTokens.padding.bottom, 3));
    expect(gap, lessThan(22));
  });

  testWidgets('zero owned progress still packs with minimal bottom padding', (
    tester,
  ) async {
    final series = _series();
    final states = <String, TrackedFigure>{};
    await _pumpCard(tester, series: series, states: states);

    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.textContaining('/'), findsOneWidget);
    final cardBottom = tester
        .getBottomLeft(find.byType(CollectionBrowseCard))
        .dy;
    final countBottom = tester.getBottomLeft(find.textContaining('/')).dy;
    expect(cardBottom - countBottom, closeTo(16, 3));
  });

  testWidgets('meta-enabled cards grow height and keep ~16dp below count', (
    tester,
  ) async {
    final series = _series();
    final states = _owned(series, 3);
    await _pumpCard(
      tester,
      series: series,
      states: states,
      cardContent: const CollectionShelfCardContentSelection([
        CollectionShelfCardContentField.brand,
      ]),
    );

    final browse = tester.widget<CollectionBrowseCard>(
      find.byType(CollectionBrowseCard),
    );
    expect(
      browse.height,
      CollectionCardTokens.minRailHeightFor(
        TextScaler.noScaling,
        metaLineCount: 1,
      ),
    );
    final cardBottom = tester
        .getBottomLeft(find.byType(CollectionBrowseCard))
        .dy;
    final countBottom = tester.getBottomLeft(find.text('3 / 12')).dy;
    expect(cardBottom - countBottom, closeTo(16, 4));
  });

  testWidgets('large text keeps title, progress, and count unclipped', (
    tester,
  ) async {
    final series = _series(name: 'Macaron Night Series Extra');
    final states = _owned(series, 4);
    await _pumpCard(
      tester,
      series: series,
      states: states,
      cardContent: const CollectionShelfCardContentSelection([
        CollectionShelfCardContentField.brand,
      ]),
      textScaler: const TextScaler.linear(1.3),
    );

    expect(tester.takeException(), isNull);
    expect(find.textContaining('Macaron'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.textContaining('/'), findsOneWidget);

    final card = tester.getSize(find.byType(CollectionBrowseCard));
    expect(
      card.height,
      greaterThan(
        CollectionCardTokens.minRailHeightFor(
          TextScaler.noScaling,
          metaLineCount: 1,
        ),
      ),
    );
  });

  testWidgets('long titles truncate without overflowing the packed card', (
    tester,
  ) async {
    final series = _series(
      name: 'Extremely Long Series Title That Must Ellipsize Cleanly On Card',
    );
    final states = _owned(series, 2);
    await _pumpCard(
      tester,
      series: series,
      states: states,
      cardContent: const CollectionShelfCardContentSelection([
        CollectionShelfCardContentField.brand,
      ]),
    );

    expect(tester.takeException(), isNull);
    final cardRect = tester.getRect(find.byType(CollectionBrowseCard));
    final titleRect = tester.getRect(find.textContaining('Extremely Long'));
    expect(titleRect.bottom, lessThanOrEqualTo(cardRect.bottom - 16));
    expect(titleRect.right, lessThanOrEqualTo(cardRect.right));
  });
}
