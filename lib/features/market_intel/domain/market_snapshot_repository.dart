import 'package:blindbox_app/features/market_intel/domain/market_snapshot.dart';

/// Read-only access to persisted market snapshots in Firestore.
abstract class MarketSnapshotRepository {
  Future<MarketSnapshot?> getSnapshotForFigure(String figureId);

  Future<MarketSnapshot?> getSnapshotForSeries(String seriesId);

  Future<List<MarketSnapshot>> getSnapshotsForSeries(String seriesId);
}
