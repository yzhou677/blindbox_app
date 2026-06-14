import 'package:blindbox_app/features/catalog/application/catalog_bundle_cache.dart';
import 'package:blindbox_app/features/catalog/models/catalog_figure.dart';
import 'package:blindbox_app/features/market_intel/data/firestore/firestore_market_snapshot_repository.dart';
import 'package:blindbox_app/features/market_intel/domain/market_snapshot.dart';
import 'package:blindbox_app/features/market_intel/domain/market_snapshot_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final marketSnapshotRepositoryProvider = Provider<MarketSnapshotRepository>(
  (ref) => FirestoreMarketSnapshotRepository(),
);

/// Figure-level market snapshot with series-level fallback via catalog lookup.
final marketSnapshotProvider =
    FutureProvider.autoDispose.family<MarketSnapshot?, String>(
  (ref, figureId) async {
    final trimmedId = figureId.trim();
    if (trimmedId.isEmpty) return null;

    final repo = ref.watch(marketSnapshotRepositoryProvider);
    final figureSnapshot = await repo.getSnapshotForFigure(trimmedId);
    if (figureSnapshot != null) return figureSnapshot;

    final bundle = CatalogBundleCache.current;
    if (bundle == null) return null;

    CatalogFigure? catalogFigure;
    for (final figure in bundle.figures) {
      if (figure.id == trimmedId) {
        catalogFigure = figure;
        break;
      }
    }
    if (catalogFigure == null) return null;

    return repo.getSnapshotForSeries(catalogFigure.seriesId);
  },
);
