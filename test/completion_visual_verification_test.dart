import 'package:blindbox_app/features/collection/application/series_completion_atmosphere.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/collection/widgets/collection_summary_section.dart';
import 'package:blindbox_app/features/collection/widgets/series_shelf_cards.dart';
import 'package:blindbox_app/core/theme/collectible_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/collection_fixtures.dart';

const _goldenDir = '../docs/completion_visual_verification';

/// Shelfy light palette without Google Fonts (goldens must run offline).
ThemeData _visualVerificationTheme() {
  const seed = Color(0xFFA892CC);
  final raw = ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.light);
  final scheme = raw.copyWith(
    primary: const Color(0xFF6652A5),
    onPrimary: const Color(0xFFFFFBFE),
    primaryContainer: const Color(0xFFE4D6F8),
    onPrimaryContainer: const Color(0xFF2A1F3D),
    secondary: const Color(0xFFE59878),
    tertiary: const Color(0xFFB49AE0),
    tertiaryContainer: const Color(0xFFF0E9FA),
    surface: const Color(0xFFFFFAFC),
    surfaceContainerLow: const Color(0xFFF5F0FA),
    surfaceContainer: const Color(0xFFEBE4F3),
    surfaceContainerHigh: const Color(0xFFE0D7EE),
    outlineVariant: const Color(0xFFC8B8D8),
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: Color.lerp(
      scheme.surfaceContainerLow,
      scheme.surface,
      0.42,
    ),
    extensions: <ThemeExtension<dynamic>>[
      CollectibleTokens.forBrightness(Brightness.light),
    ],
  );
}

ShelfSeries _seriesWithSecrets({
  required String id,
  required String name,
  required int regularCount,
  required int secretCount,
}) {
  return testShelfSeries(
    id: id,
    name: name,
    figures: [
      for (var i = 0; i < regularCount; i++)
        ShelfFigure(
          id: '${id}_reg_$i',
          seriesId: id,
          name: 'Regular $i',
          rarity: 'Regular',
          isSecret: false,
        ),
      for (var i = 0; i < secretCount; i++)
        ShelfFigure(
          id: '${id}_sec_$i',
          seriesId: id,
          name: 'Secret $i',
          rarity: 'Secret',
          isSecret: true,
        ),
    ],
  );
}

Map<String, TrackedFigure> _ownedIds(Iterable<String> ids) {
  return {
    for (final id in ids)
      id: TrackedFigure(figureId: id, state: FigureCollectionState.owned),
  };
}

void _configureGoldenSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

Future<void> _pumpCardGolden(
  WidgetTester tester, {
  required String goldenName,
  required ShelfSeries series,
  required Map<String, TrackedFigure> states,
}) async {
  final theme = _visualVerificationTheme();
  final progress = progressForSeries(series, states);
  final atmosphere = atmosphereForSeries(series, states);

  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      home: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: Center(
          child: RepaintBoundary(
            key: const Key('completion_card_golden'),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SeriesShelfCard(
                series: series,
                progress: progress,
                figureStates: states,
                atmosphere: atmosphere,
                onOpen: () {},
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 300));

  await expectLater(
    find.byKey(const Key('completion_card_golden')),
    matchesGoldenFile('$_goldenDir/$goldenName'),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('completion visual verification', () {
    testWidgets('case_a_complete_secret_missing', (tester) async {
      _configureGoldenSurface(tester);
      final series = _seriesWithSecrets(
        id: 'case_a',
        name: 'Exciting Macaron',
        regularCount: 12,
        secretCount: 1,
      );
      final states = _ownedIds([
        for (var i = 0; i < 12; i++) 'case_a_reg_$i',
      ]);
      await _pumpCardGolden(
        tester,
        goldenName: 'case_a_complete_secret_missing.png',
        series: series,
        states: states,
      );
    });

    testWidgets('case_b_master_complete', (tester) async {
      _configureGoldenSurface(tester);
      final series = _seriesWithSecrets(
        id: 'case_b',
        name: 'Exciting Macaron',
        regularCount: 12,
        secretCount: 1,
      );
      final states = _ownedIds([
        for (var i = 0; i < 12; i++) 'case_b_reg_$i',
        'case_b_sec_0',
      ]);
      await _pumpCardGolden(
        tester,
        goldenName: 'case_b_master_complete.png',
        series: series,
        states: states,
      );
    });

    testWidgets('case_c_complete_no_secret', (tester) async {
      _configureGoldenSurface(tester);
      final series = _seriesWithSecrets(
        id: 'case_c',
        name: 'Tamed Wildgrass',
        regularCount: 6,
        secretCount: 0,
      );
      final states = _ownedIds([
        for (var i = 0; i < 6; i++) 'case_c_reg_$i',
      ]);
      await _pumpCardGolden(
        tester,
        goldenName: 'case_c_complete_no_secret.png',
        series: series,
        states: states,
      );
    });

    testWidgets('in_progress_regular_denominator_8_of_12', (tester) async {
      _configureGoldenSurface(tester);
      final series = _seriesWithSecrets(
        id: 'in_prog',
        name: 'Exciting Macaron',
        regularCount: 12,
        secretCount: 1,
      );
      final states = _ownedIds([
        for (var i = 0; i < 8; i++) 'in_prog_reg_$i',
        'in_prog_sec_0',
      ]);
      await _pumpCardGolden(
        tester,
        goldenName: 'in_progress_8_of_12_secret_owned.png',
        series: series,
        states: states,
      );
    });

    testWidgets('collection_summary_completed_master', (tester) async {
      tester.view.physicalSize = const Size(500, 700);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final caseA = _seriesWithSecrets(
        id: 'sum_a',
        name: 'Series A',
        regularCount: 3,
        secretCount: 1,
      );
      final caseB = _seriesWithSecrets(
        id: 'sum_b',
        name: 'Series B',
        regularCount: 2,
        secretCount: 1,
      );
      final caseC = _seriesWithSecrets(
        id: 'sum_c',
        name: 'Series C',
        regularCount: 4,
        secretCount: 0,
      );
      final snap = CollectionSnapshot(
        shelfSeries: [caseA, caseB, caseC],
        figureStates: {
          ..._ownedIds(['sum_a_reg_0', 'sum_a_reg_1', 'sum_a_reg_2']),
          ..._ownedIds(['sum_b_reg_0', 'sum_b_reg_1', 'sum_b_sec_0']),
          ..._ownedIds([
            for (var i = 0; i < 4; i++) 'sum_c_reg_$i',
          ]),
        },
      );
      final stats = CollectionAggregateStats.fromSnapshot(snap);
      final theme = _visualVerificationTheme();

      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Scaffold(
            backgroundColor: theme.scaffoldBackgroundColor,
            body: Center(
              child: SizedBox(
                width: 500,
                child: RepaintBoundary(
                  key: const Key('summary_golden'),
                  child: CollectionSummarySection(stats: stats),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      await expectLater(
        find.byKey(const Key('summary_golden')),
        matchesGoldenFile('$_goldenDir/collection_summary.png'),
      );
    });

    testWidgets('card copy assertions for report', (tester) async {
      _configureGoldenSurface(tester);
      final theme = _visualVerificationTheme();

      Future<void> pumpCard(
        ShelfSeries series,
        Map<String, TrackedFigure> states,
      ) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: SeriesShelfCard(
              series: series,
              progress: progressForSeries(series, states),
              figureStates: states,
              atmosphere: atmosphereForSeries(series, states),
              onOpen: () {},
            ),
          ),
        );
        await tester.pump();
      }

      final caseA = _seriesWithSecrets(
        id: 'copy_a',
        name: 'Macaron',
        regularCount: 12,
        secretCount: 1,
      );
      await pumpCard(
        caseA,
        _ownedIds([for (var i = 0; i < 12; i++) 'copy_a_reg_$i']),
      );
      expect(find.text('✓ Complete'), findsOneWidget);
      expect(find.text('☆ Secret Figure still to find'), findsOneWidget);
      expect(find.textContaining('/'), findsNothing);

      final caseB = _seriesWithSecrets(
        id: 'copy_b',
        name: 'Macaron',
        regularCount: 12,
        secretCount: 1,
      );
      await pumpCard(
        caseB,
        _ownedIds([
          for (var i = 0; i < 12; i++) 'copy_b_reg_$i',
          'copy_b_sec_0',
        ]),
      );
      expect(find.textContaining('Master Complete'), findsOneWidget);
      expect(find.text('✓ Complete'), findsNothing);

      final inProg = _seriesWithSecrets(
        id: 'copy_p',
        name: 'Macaron',
        regularCount: 12,
        secretCount: 1,
      );
      await pumpCard(
        inProg,
        _ownedIds([
          for (var i = 0; i < 8; i++) 'copy_p_reg_$i',
          'copy_p_sec_0',
        ]),
      );
      expect(find.text('8 / 12'), findsOneWidget);
      expect(find.text('9 / 13'), findsNothing);
    });
  });
}
