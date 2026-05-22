import 'package:blindbox_app/features/collection/application/shelf_emotional_interpreter.dart';
import 'package:blindbox_app/features/collection/data/collection_memory_store.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/collection/domain/collection_memory_moment.dart';
import 'package:blindbox_app/features/collection/domain/shelf_interpretation_confidence.dart';

/// Derives displayable memory moments from snapshot + persisted milestones.
List<CollectionMemoryMoment> buildCollectionMemoryMoments(
  CollectionSnapshot snap,
) {
  if (snap.shelfSeries.isEmpty) return const [];

  final profile = interpretShelf(snap);
  final store = CollectionMemoryStore.instance.cached;
  final moments = <CollectionMemoryMoment>[];

  if (store.firstSecretOwnedAt != null) {
    moments.add(
      CollectionMemoryMoment(
        kind: CollectionMemoryMomentKind.firstSecretOwned,
        observedAt: store.firstSecretOwnedAt,
      ),
    );
  }

  if (store.lastCompletedSeriesId != null) {
    final series = _findSeries(snap, store.lastCompletedSeriesId!);
    if (series != null) {
      moments.add(
        CollectionMemoryMoment(
          kind: CollectionMemoryMomentKind.recentlyCompletedLineup,
          seriesId: series.id,
          seriesName: series.name,
          observedAt: store.lastCompletedAt,
        ),
      );
    }
  }

  if (profile.dominantIpId != null &&
      profile.interpretationConfidence.index >=
          ShelfInterpretationConfidence.medium.index) {
    moments.add(
      CollectionMemoryMoment(
        kind: CollectionMemoryMomentKind.dominantUniverse,
        taxonomyIpId: profile.dominantIpId,
      ),
    );
  }

  if (profile.seriesCompleteCount >= 2 &&
      profile.seriesCompleteCount == snap.shelfSeries.length) {
    moments.add(
      const CollectionMemoryMoment(
        kind: CollectionMemoryMomentKind.shelfMilestone,
      ),
    );
  }

  return moments;
}

ShelfSeries? _findSeries(CollectionSnapshot snap, String id) {
  for (final s in snap.shelfSeries) {
    if (s.id == id) return s;
  }
  return null;
}
