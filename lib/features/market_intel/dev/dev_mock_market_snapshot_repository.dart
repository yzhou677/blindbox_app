import 'package:blindbox_app/features/market_intel/domain/market_snapshot.dart';
import 'package:blindbox_app/features/market_intel/domain/market_snapshot_repository.dart';

/// DEV ONLY — in-memory snapshots mirroring market_snapshots_dev.seed.json.
///
/// Used when Firestore is not seeded locally. Remove with dev validation flow.
class DevMockMarketSnapshotRepository implements MarketSnapshotRepository {
  DevMockMarketSnapshotRepository()
      : _figureSnapshots = _allFigureSnapshots,
        _seriesSnapshots = _allSeriesSnapshots;

  final Map<String, MarketSnapshot> _figureSnapshots;
  final Map<String, MarketSnapshot> _seriesSnapshots;

  static final _computedAt = DateTime.utc(2026, 6, 14, 12);

  // ---------------------------------------------------------------------------
  // Big Into Energy — Discover gallery validation (Cases A/B/C)
  // ---------------------------------------------------------------------------

  static const _luckFigureId =
      'the_monsters_big_into_energy_vinyl_plush_pendant_luck';
  static const _bigIntoEnergySeriesId =
      'the_monsters_big_into_energy_vinyl_plush_pendant';

  // ---------------------------------------------------------------------------
  // Exciting Macaron — Collection Value UI validation
  // ---------------------------------------------------------------------------

  static const _macaronSeriesId = 'the_monsters_exciting_macaron_vinyl_face';

  static final _allFigureSnapshots = {
    _luckFigureId: MarketSnapshot(
      id: _luckFigureId,
      level: SnapshotLevel.figure,
      figureId: _luckFigureId,
      seriesId: _bigIntoEnergySeriesId,
      estimatedValueUsd: 42,
      trend: MarketTrend.rising,
      confidence: SnapshotConfidence.high,
      recentSalesCount: 18,
      priceRangeMinUsd: 38,
      priceRangeMaxUsd: 48,
      computedAt: _computedAt,
    ),
    'the_monsters_exciting_macaron_vinyl_face_chestnut_cocoa': MarketSnapshot(
      id: 'the_monsters_exciting_macaron_vinyl_face_chestnut_cocoa',
      level: SnapshotLevel.figure,
      figureId: 'the_monsters_exciting_macaron_vinyl_face_chestnut_cocoa',
      seriesId: _macaronSeriesId,
      estimatedValueUsd: 210,
      trend: MarketTrend.rising,
      confidence: SnapshotConfidence.high,
      recentSalesCount: 12,
      priceRangeMinUsd: 185,
      priceRangeMaxUsd: 240,
      computedAt: _computedAt,
    ),
    'the_monsters_exciting_macaron_vinyl_face_soymilk': MarketSnapshot(
      id: 'the_monsters_exciting_macaron_vinyl_face_soymilk',
      level: SnapshotLevel.figure,
      figureId: 'the_monsters_exciting_macaron_vinyl_face_soymilk',
      seriesId: _macaronSeriesId,
      estimatedValueUsd: 42,
      trend: MarketTrend.stable,
      confidence: SnapshotConfidence.high,
      recentSalesCount: 18,
      priceRangeMinUsd: 38,
      priceRangeMaxUsd: 48,
      computedAt: _computedAt,
    ),
    'the_monsters_exciting_macaron_vinyl_face_lychee_berry': MarketSnapshot(
      id: 'the_monsters_exciting_macaron_vinyl_face_lychee_berry',
      level: SnapshotLevel.figure,
      figureId: 'the_monsters_exciting_macaron_vinyl_face_lychee_berry',
      seriesId: _macaronSeriesId,
      estimatedValueUsd: 38,
      trend: MarketTrend.stable,
      confidence: SnapshotConfidence.high,
      recentSalesCount: 14,
      priceRangeMinUsd: 34,
      priceRangeMaxUsd: 44,
      computedAt: _computedAt,
    ),
    'the_monsters_exciting_macaron_vinyl_face_green_grape': MarketSnapshot(
      id: 'the_monsters_exciting_macaron_vinyl_face_green_grape',
      level: SnapshotLevel.figure,
      figureId: 'the_monsters_exciting_macaron_vinyl_face_green_grape',
      seriesId: _macaronSeriesId,
      estimatedValueUsd: 37,
      trend: MarketTrend.falling,
      confidence: SnapshotConfidence.high,
      recentSalesCount: 11,
      priceRangeMinUsd: 32,
      priceRangeMaxUsd: 42,
      computedAt: _computedAt,
    ),
  };

  static final _allSeriesSnapshots = {
    _bigIntoEnergySeriesId: MarketSnapshot(
      id: _bigIntoEnergySeriesId,
      level: SnapshotLevel.series,
      seriesId: _bigIntoEnergySeriesId,
      estimatedValueUsd: 37,
      trend: MarketTrend.stable,
      confidence: SnapshotConfidence.low,
      recentSalesCount: 4,
      priceRangeMinUsd: 30,
      priceRangeMaxUsd: 45,
      computedAt: _computedAt,
    ),
    // Macaron intentionally has figure snapshots only — no series doc — so
    // owned figures without a figure snapshot count as unavailable (partial
    // coverage demos).
  };

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
