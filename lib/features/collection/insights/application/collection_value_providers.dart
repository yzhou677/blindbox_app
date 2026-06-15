import 'package:blindbox_app/features/collection/application/collection_notifier.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/collection/insights/domain/shelf_value_summary.dart';
import 'package:blindbox_app/features/market_intel/application/market_snapshot_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Aggregated market-value summary for the current shelf.
///
/// Fans out to [marketSnapshotProvider] for every owned figure.  Uses the
/// figure's [ShelfFigure.catalogFigureTemplateId] as the lookup key (the
/// canonical Firestore id); falls back to [ShelfFigure.id] for custom figures.
///
/// Custom figures without a catalog template id will never have a market
/// snapshot — they count toward [ShelfValueSummary.unavailableCount].
final collectionValueProvider =
    FutureProvider.autoDispose<ShelfValueSummary>((ref) async {
  final snap = ref.watch(collectionNotifierProvider);

  // Collect all owned figure refs.
  final owned = <_FigureRef>[];
  for (final series in snap.shelfSeries) {
    for (final figure in series.figures) {
      if (snap.figureStates[figure.id]?.owned == true) {
        owned.add(
          _FigureRef(
            shelfFigureId: figure.id,
            lookupId: figure.catalogFigureTemplateId ?? figure.id,
            name: figure.name,
            imageKey: figure.imageKey,
            seriesId: series.id,
            seriesName: series.name,
          ),
        );
      }
    }
  }

  if (owned.isEmpty) return ShelfValueSummary.none;

  // Fan out — all requests run concurrently.
  final snapshots = await Future.wait(
    owned.map((f) => ref.read(marketSnapshotProvider(f.lookupId).future)),
  );

  double total = 0;
  var valuedCount = 0;
  final valuedFigures = <ValuedFigure>[];
  final seriesMap = <String, _SeriesAccum>{};

  for (var i = 0; i < owned.length; i++) {
    final fig = owned[i];
    final snapshot = snapshots[i];

    // Always track owned count per series.
    seriesMap.putIfAbsent(
      fig.seriesId,
      () => _SeriesAccum(fig.seriesName),
    ).ownedCount += 1;

    if (snapshot == null) continue;

    total += snapshot.estimatedValueUsd;
    valuedCount++;

    valuedFigures.add(
      ValuedFigure(
        shelfFigureId: fig.shelfFigureId,
        name: fig.name,
        imageKey: fig.imageKey,
        seriesId: fig.seriesId,
        seriesName: fig.seriesName,
        estimatedValueUsd: snapshot.estimatedValueUsd,
        isSeriesEstimate: snapshot.isSeriesEstimate,
      ),
    );

    final acc = seriesMap[fig.seriesId]!;
    acc.totalValue += snapshot.estimatedValueUsd;
    acc.valuedCount += 1;
  }

  valuedFigures.sort(
    (a, b) => b.estimatedValueUsd.compareTo(a.estimatedValueUsd),
  );

  final seriesBreakdown =
      seriesMap.entries
          .where((e) => e.value.valuedCount > 0)
          .map(
            (e) => SeriesValueEntry(
              seriesId: e.key,
              seriesName: e.value.seriesName,
              totalValueUsd: e.value.totalValue,
              valuedFigureCount: e.value.valuedCount,
              ownedFigureCount: e.value.ownedCount,
            ),
          )
          .toList()
        ..sort((a, b) => b.totalValueUsd.compareTo(a.totalValueUsd));

  return ShelfValueSummary(
    totalValueUsd: total,
    ownedCount: owned.length,
    valuedCount: valuedCount,
    unavailableCount: owned.length - valuedCount,
    topFigures: valuedFigures.take(5).toList(),
    seriesBreakdown: seriesBreakdown,
    tier: _computeTier(total),
  );
});

CollectionValueTier _computeTier(double total) {
  if (total == 0) return CollectionValueTier.empty;
  if (total < 200) return CollectionValueTier.small;
  if (total < 1000) return CollectionValueTier.medium;
  if (total < 5000) return CollectionValueTier.large;
  return CollectionValueTier.massive;
}

// ---------------------------------------------------------------------------
// Internal helpers
// ---------------------------------------------------------------------------

class _FigureRef {
  _FigureRef({
    required this.shelfFigureId,
    required this.lookupId,
    required this.name,
    required this.imageKey,
    required this.seriesId,
    required this.seriesName,
  });

  final String shelfFigureId;

  /// Key passed to [marketSnapshotProvider] — catalog template id when set.
  final String lookupId;

  final String name;
  final String? imageKey;
  final String seriesId;
  final String seriesName;
}

class _SeriesAccum {
  _SeriesAccum(this.seriesName);

  final String seriesName;
  double totalValue = 0;
  int valuedCount = 0;
  int ownedCount = 0;
}
