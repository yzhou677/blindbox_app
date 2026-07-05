import 'package:blindbox_app/core/router/app_router.dart';
import 'package:blindbox_app/core/theme/app_theme.dart';
import 'package:blindbox_app/core/theme/collectible_motion.dart';
import 'package:blindbox_app/core/theme/collectible_typography.dart';
import 'package:blindbox_app/features/collection/application/collection_notifier.dart';
import 'package:blindbox_app/features/collection/application/master_complete_celebration_controller.dart';
import 'package:blindbox_app/features/collection/bootstrap/collection_app_bootstrap.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/collection/domain/master_complete_transition.dart';
import 'package:blindbox_app/features/collection/presentation/collection_vocabulary.dart';
import 'package:blindbox_app/features/collection/widgets/master_complete_achievement_overlay.dart';
import 'package:blindbox_app/features/collection/widgets/master_complete_celebration_host.dart';
import 'package:blindbox_app/features/collection/widgets/series_completion_stat_slot.dart';
import 'package:blindbox_app/features/collection/widgets/series_shelf_cards.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/collection_fixtures.dart';

Finder get _achievementLabelFinder =>
    find.byKey(const Key('master_complete_achievement_label'));

Finder get _achievementParticlesFinder =>
    find.byKey(const Key('master_complete_achievement_particles'));

Finder get _masterStatLineFinder =>
    find.byKey(const Key('master_complete_stat_line'));

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

TextStyle _masterLineStyle() {
  return CollectibleTypography.shelfMasterCompleteStatLine(
    ThemeData.light().textTheme,
    ThemeData.light().colorScheme,
  );
}

void main() {
  group('newlyMasterCompleteSeries', () {
    test('detects false to true on live figure change', () {
      final series = _masterSeries();
      final previous = CollectionSnapshot(
        shelfSeries: [series],
        figureStates: _ownedRegularOnly(series),
      );
      final next = CollectionSnapshot(
        shelfSeries: [series],
        figureStates: _ownedAll(series),
      );

      expect(newlyMasterCompleteSeries(previous, next).map((s) => s.id), [
        'master_series',
      ]);
    });

    test('ignores series already master complete', () {
      final series = _masterSeries();
      final snap = CollectionSnapshot(
        shelfSeries: [series],
        figureStates: _ownedAll(series),
      );

      expect(newlyMasterCompleteSeries(snap, snap), isEmpty);
    });

    test('ignores brand-new shelf row that mounts as master', () {
      final series = _masterSeries();
      final previous = CollectionSnapshot.emptyTest();
      final next = CollectionSnapshot(
        shelfSeries: [series],
        figureStates: _ownedAll(series),
      );

      expect(newlyMasterCompleteSeries(previous, next), isEmpty);
    });
  });

  group('MasterCompleteCrownSparkleSequence', () {
    test('sparkle windows never overlap', () {
      final list = MasterCompleteCrownSparkleSequence.sparkles;
      for (var i = 0; i < list.length; i++) {
        for (var j = i + 1; j < list.length; j++) {
          final a = list[i];
          final b = list[j];
          final overlaps = a.start < b.end && b.start < a.end;
          expect(overlaps, isFalse, reason: '${a.id} vs ${b.id}');
        }
      }
    });

    test('only one sparkle active at sampled timeline points', () {
      for (var i = 1; i < 120; i++) {
        final t = i / 120.0;
        expect(
          MasterCompleteCrownSparkleSequence.activeAt(t).length,
          lessThanOrEqualTo(1),
          reason: 'at t=$t',
        );
      }
    });

    test('five distinct sparkle beats after entrance', () {
      var seen = 0;
      var wasActive = false;
      for (var i = 0; i < 200; i++) {
        final t = i / 200.0;
        final active = MasterCompleteCrownSparkleSequence.activeAt(t).isNotEmpty;
        if (active && !wasActive) seen++;
        wasActive = active;
      }
      expect(seen, 5);
    });

    test('sparkle opacity and scale peak mid-life', () {
      expect(MasterCompleteCrownSparkleSequence.sparkleOpacity(0), 0);
      expect(
        MasterCompleteCrownSparkleSequence.sparkleOpacity(0.45),
        greaterThan(0.8),
      );
      expect(MasterCompleteCrownSparkleSequence.sparkleOpacity(1), lessThan(0.2));
      expect(MasterCompleteCrownSparkleSequence.sparkleScale(0), closeTo(1, 0.01));
      expect(
        MasterCompleteCrownSparkleSequence.sparkleScale(0.45),
        closeTo(1.15, 0.02),
      );
    });
  });

  group('MasterCompleteCelebrationNotifier', () {
    test('queues while presenting and drains after finish', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(masterCompleteCelebrationProvider.notifier);

      notifier.celebrate();
      expect(container.read(masterCompleteCelebrationProvider)?.token, 1);
      expect(notifier.isPresenting, isFalse);

      notifier.onPresentationStarted();
      expect(notifier.isPresenting, isTrue);

      notifier.celebrate();
      expect(notifier.queuedCount, 1);

      notifier.onPresentationFinished();
      expect(notifier.isPresenting, isFalse);
      expect(container.read(masterCompleteCelebrationProvider)?.token, 2);
      expect(notifier.queuedCount, 0);
    });

    test('onPresentationFailed skips current and drains queue', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(masterCompleteCelebrationProvider.notifier);

      notifier.celebrate();
      notifier.celebrate();
      expect(container.read(masterCompleteCelebrationProvider)?.token, 1);
      expect(notifier.queuedCount, 1);

      notifier.onPresentationFailed();
      expect(notifier.isPresenting, isFalse);
      expect(container.read(masterCompleteCelebrationProvider)?.token, 2);
      expect(notifier.queuedCount, 0);
    });
  });

  group('MasterCompleteAchievementTiming', () {
    test('entrance eases from zero opacity and 98% scale', () {
      expect(MasterCompleteAchievementTiming.masterOpacity(0), 0);
      expect(
        MasterCompleteAchievementTiming.entranceScale(0),
        closeTo(0.98, 0.001),
      );
      expect(
        MasterCompleteAchievementTiming.masterOpacity(0.115),
        closeTo(1, 0.02),
      );
      expect(
        MasterCompleteAchievementTiming.entranceScale(0.115),
        closeTo(1, 0.02),
      );
    });

    test('scrim and blur peak around hold phase', () {
      expect(
        MasterCompleteAchievementTiming.scrimOpacity(0.4),
        closeTo(0.13, 0.01),
      );
      expect(
        MasterCompleteAchievementTiming.blurSigma(0.4),
        closeTo(5.5, 0.1),
      );
    });
  });

  group('MasterCompleteAchievementOverlay', () {
    testWidgets('shows label and particles mid celebration', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: MasterCompleteAchievementOverlay(
              onFinished: () {},
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(_achievementLabelFinder, findsOneWidget);
      expect(_achievementParticlesFinder, findsOneWidget);
      expect(
        find.byKey(const Key('master_complete_achievement_backdrop')),
        findsOneWidget,
      );
      expect(find.text(CollectionVocabulary.masterComplete), findsOneWidget);
    });

    testWidgets('dismisses and notifies host after full duration', (tester) async {
      var finished = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: MasterCompleteAchievementOverlay(
              onFinished: () => finished = true,
            ),
          ),
        ),
      );

      await tester.pump();
      for (var i = 0; i < 24 && !finished; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      expect(finished, isTrue);
    });

    testWidgets('blocks interaction while visible', (tester) async {
      var tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: Stack(
              fit: StackFit.expand,
              children: [
                Center(
                  child: TextButton(
                    onPressed: () => tapped = true,
                    child: const Text('underlay'),
                  ),
                ),
                MasterCompleteAchievementOverlay(
                  onFinished: () {},
                ),
              ],
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      await tester.tap(find.text('underlay'), warnIfMissed: false);
      await tester.pump();

      expect(tapped, isFalse);
    });

    testWidgets('respects reduced motion', (tester) async {
      var finished = false;

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: MasterCompleteAchievementOverlay(
              onFinished: () => finished = true,
            ),
          ),
        ),
      );

      await tester.pump();
      expect(_achievementParticlesFinder, findsNothing);
      await tester.pump();
      expect(finished, isTrue);
    });
  });

  group('MasterCompleteCelebrationHost', () {
    testWidgets('presents overlay above modal sheet immediately', (tester) async {
      final series = _masterSeries();
      CollectionAppBootstrap.prime(
        CollectionSnapshot(
          shelfSeries: [series],
          figureStates: _ownedRegularOnly(series),
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            navigatorKey: rootNavigatorKey,
            theme: AppTheme.light(),
            home: Builder(
              builder: (context) {
                return MasterCompleteCelebrationHost(
                  child: Scaffold(
                    body: TextButton(
                      onPressed: () => showModalBottomSheet<void>(
                        context: context,
                        builder: (_) => const SizedBox(
                          height: 240,
                          child: Center(child: Text('figures sheet')),
                        ),
                      ),
                      child: const Text('open sheet'),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('open sheet'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final container = ProviderScope.containerOf(
        tester.element(find.byType(MasterCompleteCelebrationHost)),
      );
      container
          .read(masterCompleteCelebrationProvider.notifier)
          .celebrate();

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 32));

      expect(_achievementLabelFinder, findsOneWidget);
      expect(_achievementParticlesFinder, findsOneWidget);
      expect(find.text('figures sheet'), findsOneWidget);
    });
  });

  group('CollectionNotifier master complete celebration', () {
    testWidgets('fires global overlay when secret is owned', (tester) async {
      final series = _masterSeries();
      CollectionAppBootstrap.prime(
        CollectionSnapshot(
          shelfSeries: [series],
          figureStates: _ownedRegularOnly(series),
        ),
      );

      late ProviderContainer container;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            navigatorKey: rootNavigatorKey,
            theme: AppTheme.light(),
            home: Builder(
              builder: (context) {
                container = ProviderScope.containerOf(context);
                return MasterCompleteCelebrationHost(
                  child: const Scaffold(body: SizedBox()),
                );
              },
            ),
          ),
        ),
      );

      container.read(collectionNotifierProvider.notifier);
      container.read(collectionNotifierProvider.notifier).cycleFigure('sec_0');
      container.read(collectionNotifierProvider.notifier).cycleFigure('sec_0');

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 32));

      expect(_achievementLabelFinder, findsOneWidget);
      expect(
        container.read(masterCompleteCelebrationProvider)?.token,
        greaterThan(0),
      );
    });
  });

  group('SeriesCompletionStatSlot', () {
    testWidgets('master complete is static text only', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SeriesCompletionStatSlot(
              level: SeriesCompletionStatLevel.masterComplete,
              statPrimary: 'ignored',
              masterTextStyle: _masterLineStyle(),
              completeTextStyle: const TextStyle(),
              progressTextStyle: const TextStyle(),
              colorScheme: ThemeData.light().colorScheme,
            ),
          ),
        ),
      );

      expect(_masterStatLineFinder, findsOneWidget);
      expect(find.textContaining('Master Complete'), findsOneWidget);
      expect(find.byKey(const Key('series_complete_stat_glow')), findsNothing);
      expect(
        tester.getSemantics(_masterStatLineFinder),
        matchesSemantics(label: CollectionVocabulary.masterComplete),
      );
    });

    testWidgets('series complete shows static blue glow', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SeriesCompletionStatSlot(
              level: SeriesCompletionStatLevel.seriesComplete,
              statPrimary: '✓ Complete',
              masterTextStyle: _masterLineStyle(),
              completeTextStyle: const TextStyle(fontWeight: FontWeight.w600),
              progressTextStyle: const TextStyle(),
              colorScheme: ThemeData.light().colorScheme,
            ),
          ),
        ),
      );

      expect(find.text('✓ Complete'), findsOneWidget);
      expect(find.byKey(const Key('series_complete_stat_glow')), findsOneWidget);
    });
  });

  group('SeriesShelfCard', () {
    testWidgets('shows static master stat line without card celebration', (
      tester,
    ) async {
      final series = _masterSeries();

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
              figureStates: _ownedAll(series),
              onOpen: () {},
            ),
          ),
        ),
      );

      expect(_masterStatLineFinder, findsOneWidget);
      expect(_achievementParticlesFinder, findsNothing);
    });
  });
}
