import 'package:blindbox_app/core/theme/app_theme.dart';
import 'package:blindbox_app/core/theme/collectible_motion.dart';
import 'package:blindbox_app/core/theme/collectible_typography.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/collection/presentation/collection_vocabulary.dart';
import 'package:blindbox_app/features/collection/widgets/master_complete_celebration.dart';
import 'package:blindbox_app/features/collection/widgets/series_shelf_cards.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/collection_fixtures.dart';

TextStyle _masterLineStyle() {
  return CollectibleTypography.shelfMasterCompleteStatLine(
    ThemeData.light().textTheme,
    ThemeData.light().colorScheme,
  );
}

Finder get _masterBadgeFinder => find.textContaining('Master Complete');

Finder get _particleFinder =>
    find.byKey(const Key('master_complete_celebration_particles'));

ShelfSeries _masterSeries() {
  return testShelfSeries(
    id: 'master_series',
    name: 'Master Series',
    figures: [
      const ShelfFigure(
        id: 'reg_0',
        seriesId: 'master_series',
        name: 'Regular',
        rarity: 'Regular',
        isSecret: false,
      ),
      const ShelfFigure(
        id: 'sec_0',
        seriesId: 'master_series',
        name: 'Secret',
        rarity: 'Secret',
        isSecret: true,
      ),
    ],
  );
}

Map<String, TrackedFigure> _ownedRegularOnly(ShelfSeries series) {
  return {
    for (final f in series.figures)
      if (!f.isSecret)
        f.id: TrackedFigure(
          figureId: f.id,
          state: FigureCollectionState.owned,
        ),
  };
}

Map<String, TrackedFigure> _ownedAll(ShelfSeries series) {
  return {
    for (final f in series.figures)
      f.id: TrackedFigure(
        figureId: f.id,
        state: FigureCollectionState.owned,
      ),
  };
}

void main() {
  group('masterCompleteAmbientSparkleOpacity', () {
    test('peaks mid-curve and returns zero at rest', () {
      expect(masterCompleteAmbientSparkleOpacity(0), 0);
      expect(masterCompleteAmbientSparkleOpacity(1), 0);
      expect(
        masterCompleteAmbientSparkleOpacity(0.5),
        closeTo(0.46, 0.01),
      );
    });
  });

  group('MasterCompleteCelebrationBadge', () {
    testWidgets('does not animate on first mount when already master complete', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MasterCompleteCelebrationBadge(
              isMasterComplete: true,
              celebrateTick: 0,
              ambientStaggerSeed: 'test',
              textStyle: _masterLineStyle(),
            ),
          ),
        ),
      );

      expect(_masterBadgeFinder, findsOneWidget);
      expect(_particleFinder, findsNothing);

      await tester.pump(CollectibleMotion.masterCompleteCelebration);
      expect(_particleFinder, findsNothing);
    });

    testWidgets('plays celebration when celebrateTick increments', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: _CelebrateTickHarness(textStyle: _masterLineStyle()),
          ),
        ),
      );

      expect(_particleFinder, findsNothing);

      final celebrateHarness = tester.state<_CelebrateTickHarnessState>(
        find.byType(_CelebrateTickHarness),
      );
      celebrateHarness.bumpTick();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 32));

      expect(_particleFinder, findsOneWidget);

      await tester.pump(CollectibleMotion.masterCompleteCelebration);
      await tester.pump();

      expect(_particleFinder, findsNothing);
    });

    testWidgets('respects reduced motion — static badge only', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: Scaffold(
              body: MasterCompleteCelebrationBadge(
                isMasterComplete: true,
                celebrateTick: 0,
              ambientStaggerSeed: 'test',
                textStyle: _masterLineStyle(),
              ),
            ),
          ),
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: Scaffold(
              body: MasterCompleteCelebrationBadge(
                isMasterComplete: true,
                celebrateTick: 1,
              ambientStaggerSeed: 'test',
                textStyle: _masterLineStyle(),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(_particleFinder, findsNothing);
      expect(_masterBadgeFinder, findsOneWidget);
    });

    testWidgets('shows fallback when not master complete', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MasterCompleteCelebrationBadge(
              isMasterComplete: false,
              celebrateTick: 0,
              ambientStaggerSeed: 'test',
              textStyle: TextStyle(),
              fallback: Text('3 of 4'),
            ),
          ),
        ),
      );

      expect(find.text('3 of 4'), findsOneWidget);
      expect(_masterBadgeFinder, findsNothing);
    });
  });

  group('SeriesShelfCard master complete transition', () {
    testWidgets('increments celebrate tick only on false to true', (
      tester,
    ) async {
      final series = _masterSeries();
      var states = _ownedRegularOnly(series);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: _ShelfCardHarness(
              series: series,
              figureStates: states,
            ),
          ),
        ),
      );

      expect(_masterBadgeFinder, findsNothing);

      final shelfHarness = tester.state<_ShelfCardHarnessState>(
        find.byType(_ShelfCardHarness),
      );
      shelfHarness.bumpToMaster();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 32));

      expect(_masterBadgeFinder, findsOneWidget);
      expect(_particleFinder, findsOneWidget);
    });

    testWidgets('does not celebrate when already master complete on mount', (
      tester,
    ) async {
      final series = _masterSeries();
      final states = _ownedAll(series);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: SeriesShelfCard(
              series: series,
              progress: const SeriesProgressCounts(
                owned: 2,
                wishlist: 0,
                missing: 0,
              ),
              figureStates: states,
              onOpen: () {},
            ),
          ),
        ),
      );

      expect(_masterBadgeFinder, findsOneWidget);
      expect(_particleFinder, findsNothing);
    });
  });
}

class _CelebrateTickHarness extends StatefulWidget {
  const _CelebrateTickHarness({required this.textStyle});

  final TextStyle textStyle;

  @override
  State<_CelebrateTickHarness> createState() => _CelebrateTickHarnessState();
}

class _CelebrateTickHarnessState extends State<_CelebrateTickHarness> {
  var _tick = 0;

  void bumpTick() => setState(() => _tick++);

  @override
  Widget build(BuildContext context) {
    return MasterCompleteCelebrationBadge(
      isMasterComplete: true,
      celebrateTick: _tick,
      ambientStaggerSeed: 'harness',
      textStyle: widget.textStyle,
    );
  }
}

class _ShelfCardHarness extends StatefulWidget {
  const _ShelfCardHarness({
    required this.series,
    required this.figureStates,
  });

  final ShelfSeries series;
  final Map<String, TrackedFigure> figureStates;

  @override
  State<_ShelfCardHarness> createState() => _ShelfCardHarnessState();
}

class _ShelfCardHarnessState extends State<_ShelfCardHarness> {
  late Map<String, TrackedFigure> _states;

  @override
  void initState() {
    super.initState();
    _states = widget.figureStates;
  }

  void bumpToMaster() => setState(() => _states = _ownedAll(widget.series));

  SeriesProgressCounts get _progress {
    var owned = 0;
    var missing = 0;
    for (final f in widget.series.figures) {
      if (_states[f.id]?.owned == true) {
        owned++;
      } else {
        missing++;
      }
    }
    return SeriesProgressCounts(owned: owned, wishlist: 0, missing: missing);
  }

  @override
  Widget build(BuildContext context) {
    return SeriesShelfCard(
      series: widget.series,
      progress: _progress,
      figureStates: _states,
      onOpen: () {},
    );
  }
}
