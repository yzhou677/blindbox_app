import 'package:blindbox_app/core/theme/app_theme.dart';
import 'package:blindbox_app/features/collection/bootstrap/collection_app_bootstrap.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/collection/insights/application/collection_value_providers.dart';
import 'package:blindbox_app/features/collection/insights/presentation/collector_type_copy.dart';
import 'package:blindbox_app/features/collection/widgets/collection_summary_section.dart';
import 'package:blindbox_app/features/market_intel/application/market_snapshot_providers.dart';
import 'package:blindbox_app/features/market_intel/dev/dev_mock_market_snapshot_repository.dart';
import 'package:blindbox_app/features/market_intel/domain/market_snapshot.dart';
import 'package:blindbox_app/features/market_intel/domain/market_snapshot_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('CollectionSummarySection shows shelf value with dev mock repo',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    CollectionAppBootstrap.prime(
      CollectionSnapshot(
        shelfSeries: [
          ShelfSeries(
            id: 'series_macaron',
            name: 'Exciting Macaron',
            brand: 'POP MART',
            ipName: 'The Monsters',
            figures: const [
              ShelfFigure(
                id: 'fig_soy',
                seriesId: 'series_macaron',
                name: 'Soymilk',
                rarity: 'Regular',
                isSecret: false,
                catalogFigureTemplateId:
                    'the_monsters_exciting_macaron_vinyl_face_soymilk',
              ),
              ShelfFigure(
                id: 'fig_toffee',
                seriesId: 'series_macaron',
                name: 'Toffee',
                rarity: 'Regular',
                isSecret: false,
                catalogFigureTemplateId:
                    'the_monsters_exciting_macaron_vinyl_face_toffee',
              ),
            ],
            shelfAccent: Color(0xFFE4F2EA),
            catalogTemplateId: 'the_monsters_exciting_macaron_vinyl_face',
          ),
        ],
        figureStates: {
          'fig_soy': TrackedFigure(
            figureId: 'fig_soy',
            state: FigureCollectionState.owned,
          ),
          'fig_toffee': TrackedFigure(
            figureId: 'fig_toffee',
            state: FigureCollectionState.owned,
          ),
        },
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          marketSnapshotRepositoryProvider.overrideWithValue(
            DevMockMarketSnapshotRepository(),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) {
                final summary = ref.watch(collectionValueProvider);
                return CollectionSummarySection(
                  stats: const CollectionAggregateStats(
                    inCollection: 2,
                    wantListCount: 0,
                  ),
                  shelfValue: summary.valueOrNull,
                  onInsightsTap: () {},
                );
              },
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.textContaining('Est. shelf value'), findsOneWidget);
    expect(find.textContaining(r'$42'), findsOneWidget);
    expect(find.textContaining('Based on 1 of 2 figures'), findsOneWidget);
    expect(find.textContaining('includes estimates'), findsNothing);
    expect(find.text(CollectorTypeCopy.homeInsightsEntry), findsOneWidget);
    expect(find.text(CollectorTypeCopy.entryCta), findsNothing);
    expect(find.text('Shelf value breakdown'), findsNothing);
  });

  testWidgets('CollectionSummarySection appends estimates qualifier for series mix',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    CollectionAppBootstrap.prime(
      CollectionSnapshot(
        shelfSeries: [
          ShelfSeries(
            id: 'series_test',
            name: 'Big Into Energy',
            brand: 'POP MART',
            ipName: 'The Monsters',
            figures: const [
              ShelfFigure(
                id: 'fig_luck',
                seriesId: 'series_test',
                name: 'Luck',
                rarity: 'Regular',
                isSecret: false,
                catalogFigureTemplateId:
                    'the_monsters_big_into_energy_vinyl_plush_pendant_luck',
              ),
              ShelfFigure(
                id: 'fig_hope',
                seriesId: 'series_test',
                name: 'Hope',
                rarity: 'Regular',
                isSecret: false,
                catalogFigureTemplateId:
                    'the_monsters_big_into_energy_vinyl_plush_pendant_hope',
              ),
            ],
            shelfAccent: Color(0xFFE4F2EA),
            catalogTemplateId:
                'the_monsters_big_into_energy_vinyl_plush_pendant',
          ),
        ],
        figureStates: {
          'fig_luck': TrackedFigure(
            figureId: 'fig_luck',
            state: FigureCollectionState.owned,
          ),
          'fig_hope': TrackedFigure(
            figureId: 'fig_hope',
            state: FigureCollectionState.owned,
          ),
        },
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          marketSnapshotRepositoryProvider.overrideWithValue(_SeriesMixRepo()),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) {
                final summary = ref.watch(collectionValueProvider);
                return CollectionSummarySection(
                  stats: const CollectionAggregateStats(
                    inCollection: 2,
                    wantListCount: 0,
                  ),
                  shelfValue: summary.valueOrNull,
                  onInsightsTap: () {},
                );
              },
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(
      find.textContaining('Based on 2 of 2 figures · includes estimates'),
      findsOneWidget,
    );
  });
}

class _SeriesMixRepo implements MarketSnapshotRepository {
  @override
  Future<MarketSnapshot?> getSnapshotForFigure(String figureId) async {
    if (figureId ==
        'the_monsters_big_into_energy_vinyl_plush_pendant_luck') {
      return MarketSnapshot(
        id: figureId,
        level: SnapshotLevel.figure,
        figureId: figureId,
        seriesId: 'the_monsters_big_into_energy_vinyl_plush_pendant',
        estimatedValueUsd: 42,
        trend: MarketTrend.stable,
        confidence: SnapshotConfidence.high,
        recentSalesCount: 18,
        computedAt: DateTime.utc(2026, 6, 15),
      );
    }
    if (figureId ==
        'the_monsters_big_into_energy_vinyl_plush_pendant_hope') {
      return MarketSnapshot(
        id: 'the_monsters_big_into_energy_vinyl_plush_pendant',
        level: SnapshotLevel.series,
        seriesId: 'the_monsters_big_into_energy_vinyl_plush_pendant',
        estimatedValueUsd: 37,
        trend: MarketTrend.stable,
        confidence: SnapshotConfidence.low,
        recentSalesCount: 4,
        computedAt: DateTime.utc(2026, 6, 15),
      );
    }
    return null;
  }

  @override
  Future<MarketSnapshot?> getSnapshotForSeries(String seriesId) async => null;

  @override
  Future<List<MarketSnapshot>> getSnapshotsForSeries(String seriesId) async =>
      [];
}
