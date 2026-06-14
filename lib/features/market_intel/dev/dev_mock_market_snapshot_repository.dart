import 'package:blindbox_app/features/market_intel/domain/market_snapshot.dart';
import 'package:blindbox_app/features/market_intel/domain/market_snapshot_repository.dart';

/// DEV ONLY — in-memory snapshots mirroring market_snapshots_dev.seed.json.
///
/// Used when Firestore is not seeded locally. Remove with dev validation flow.
class DevMockMarketSnapshotRepository implements MarketSnapshotRepository {
  DevMockMarketSnapshotRepository()
      : _figureSnapshots = {
          'the_monsters_big_into_energy_vinyl_plush_pendant_luck':
              _luckFigureSnapshot,
        },
        _seriesSnapshots = {
          'the_monsters_big_into_energy_vinyl_plush_pendant': _seriesSnapshot,
        };

  final Map<String, MarketSnapshot> _figureSnapshots;
  final Map<String, MarketSnapshot> _seriesSnapshots;

  static final _computedAt = DateTime.utc(2026, 6, 14, 12);

  static final _luckFigureSnapshot = MarketSnapshot(
    id: 'the_monsters_big_into_energy_vinyl_plush_pendant_luck',
    level: SnapshotLevel.figure,
    figureId: 'the_monsters_big_into_energy_vinyl_plush_pendant_luck',
    seriesId: 'the_monsters_big_into_energy_vinyl_plush_pendant',
    estimatedValueUsd: 42,
    trend: MarketTrend.rising,
    confidence: SnapshotConfidence.high,
    recentSalesCount: 18,
    priceRangeMinUsd: 38,
    priceRangeMaxUsd: 48,
    computedAt: _computedAt,
  );

  static final _seriesSnapshot = MarketSnapshot(
    id: 'the_monsters_big_into_energy_vinyl_plush_pendant',
    level: SnapshotLevel.series,
    seriesId: 'the_monsters_big_into_energy_vinyl_plush_pendant',
    estimatedValueUsd: 37,
    trend: MarketTrend.stable,
    confidence: SnapshotConfidence.low,
    recentSalesCount: 4,
    priceRangeMinUsd: 30,
    priceRangeMaxUsd: 45,
    computedAt: _computedAt,
  );

  @override
  Future<MarketSnapshot?> getSnapshotForFigure(String figureId) async {
    return _figureSnapshots[figureId.trim()];
  }

  @override
  Future<MarketSnapshot?> getSnapshotForSeries(String seriesId) async {
    return _seriesSnapshots[seriesId.trim()];
  }

  @override
  Future<List<MarketSnapshot>> getSnapshotsForSeries(String seriesId) async {
    final id = seriesId.trim();
    return _figureSnapshots.values
        .where((snapshot) => snapshot.seriesId == id)
        .toList(growable: false);
  }
}
