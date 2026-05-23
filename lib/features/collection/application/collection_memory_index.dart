import 'package:blindbox_app/features/collection/application/collection_evolution_interpreter.dart';
import 'package:blindbox_app/features/collection/application/shelf_emotional_interpreter.dart';
import 'package:blindbox_app/features/collection/data/collection_memory_store.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/collection/domain/shelf_era.dart';
import 'package:blindbox_app/features/collection/domain/collection_memory_moment.dart';
import 'package:blindbox_app/features/collection/presentation/collection_memory_editorial.dart';
import 'package:blindbox_app/features/collection/domain/shelf_interpretation_confidence.dart';

/// Derives displayable memory moments from snapshot + persisted milestones.
List<CollectionMemoryMoment> buildCollectionMemoryMoments(
  CollectionSnapshot snap,
) {
  if (snap.shelfSeries.isEmpty) return const [];

  final profile = interpretShelf(snap);
  final store = CollectionMemoryStore.instance.cached;
  final moments = <CollectionMemoryMoment>[];
  final now = DateTime.now();

  if (store.lastCompletedSeriesId != null && store.lastCompletedAt != null) {
    final age = now.difference(store.lastCompletedAt!);
    if (age <= CollectionMemoryEditorial.recentCompletionWindow) {
      final series = _findSeries(snap, store.lastCompletedSeriesId!);
      if (series != null && _isSeriesComplete(snap, series.id)) {
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
  }

  final priorEra = _evolutionPriorEra(store);
  final evolution = interpretCollectionEvolution(
    snap: snap,
    priorEra: priorEra,
  );
  if (evolution != null) {
    moments.add(
      const CollectionMemoryMoment(
        kind: CollectionMemoryMomentKind.shelfEvolution,
      ),
    );
  }

  final longLoved = _longLovedUniverse(snap, store.ipSeriesDepth);
  if (longLoved != null) {
    moments.add(longLoved);
  }

  if (store.firstSecretOwnedAt != null && _hasOwnedSecret(snap)) {
    moments.add(
      CollectionMemoryMoment(
        kind: CollectionMemoryMomentKind.firstSecretOwned,
        observedAt: store.firstSecretOwnedAt,
      ),
    );
  }

  if (profile.dominantIpId != null &&
      profile.interpretationConfidence.index >=
          ShelfInterpretationConfidence.medium.index) {
    moments.add(
      CollectionMemoryMoment(
        kind: CollectionMemoryMomentKind.dominantUniverse,
        taxonomyIpId: profile.dominantIpId,
        universeLabel: _ipLabel(snap, profile.dominantIpId!),
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

  if (store.firstSeriesAddedAt != null) {
    final age = now.difference(store.firstSeriesAddedAt!);
    if (age >= CollectionMemoryEditorial.shelfGrowingMinAge &&
        snap.shelfSeries.length >= 2) {
      moments.add(
        CollectionMemoryMoment(
          kind: CollectionMemoryMomentKind.shelfGrowing,
          observedAt: store.firstSeriesAddedAt,
        ),
      );
    }
  }

  return moments;
}

/// At most one calm memory whisper for the collection summary.
CollectionMemoryMoment? pickPrimaryMemoryMoment(
  CollectionSnapshot snap,
  List<CollectionMemoryMoment> moments,
) {
  if (moments.isEmpty) return null;

  CollectionMemoryMoment? pick(CollectionMemoryMomentKind kind) {
    for (final m in moments) {
      if (m.kind == kind) return m;
    }
    return null;
  }

  return pick(CollectionMemoryMomentKind.recentlyCompletedLineup) ??
      pick(CollectionMemoryMomentKind.shelfEvolution) ??
      pick(CollectionMemoryMomentKind.longLovedUniverse) ??
      pick(CollectionMemoryMomentKind.firstSecretOwned) ??
      pick(CollectionMemoryMomentKind.dominantUniverse) ??
      pick(CollectionMemoryMomentKind.shelfMilestone) ??
      pick(CollectionMemoryMomentKind.shelfGrowing) ??
      moments.first;
}

/// Resolves whisper text including evolution (not stored as a moment line).
String? resolveCollectionMemoryWhisper(CollectionSnapshot snap) {
  final moments = buildCollectionMemoryMoments(snap);
  final primary = pickPrimaryMemoryMoment(snap, moments);
  if (primary == null) return null;

  if (primary.kind == CollectionMemoryMomentKind.shelfEvolution) {
    final evolution = interpretCollectionEvolution(
      snap: snap,
      priorEra: _evolutionPriorEra(CollectionMemoryStore.instance.cached),
    );
    if (evolution != null) {
      return CollectionMemoryEditorial.whisperForEvolution(evolution);
    }
    return null;
  }

  return CollectionMemoryEditorial.whisperForMoment(primary);
}

CollectionMemoryMoment? _longLovedUniverse(
  CollectionSnapshot snap,
  Map<String, int> depth,
) {
  if (depth.isEmpty) return null;

  final entries = depth.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  final top = entries.first;
  if (top.value < 2) return null;

  final second = entries.length > 1 ? entries[1].value : 0;
  if (top.value < 3 && top.value <= second) return null;

  return CollectionMemoryMoment(
    kind: CollectionMemoryMomentKind.longLovedUniverse,
    taxonomyIpId: top.key,
    universeLabel: _ipLabel(snap, top.key),
  );
}

String? _ipLabel(CollectionSnapshot snap, String ipId) {
  for (final s in snap.shelfSeries) {
    if (s.taxonomyIpId == ipId) {
      return shelfSeriesIpLabel(s).trim().isNotEmpty
          ? shelfSeriesIpLabel(s)
          : s.ipName;
    }
  }
  return null;
}

ShelfSeries? _findSeries(CollectionSnapshot snap, String id) {
  for (final s in snap.shelfSeries) {
    if (s.id == id) return s;
  }
  return null;
}

bool _isSeriesComplete(CollectionSnapshot snap, String seriesId) {
  for (final series in snap.shelfSeries) {
    if (series.id != seriesId) continue;
    final p = progressForSeries(series, snap.figureStates);
    return series.figureCount > 0 && p.owned >= series.figureCount;
  }
  return false;
}

const _evolutionWindow = Duration(days: 45);

ShelfEra? _evolutionPriorEra(CollectionMemoryData store) {
  final prior = store.priorEraForEvolution;
  if (prior == null) return null;
  final at = store.priorEraSetAt;
  if (at != null && DateTime.now().difference(at) > _evolutionWindow) {
    return null;
  }
  return prior;
}

bool _hasOwnedSecret(CollectionSnapshot snap) {
  for (final series in snap.shelfSeries) {
    for (final fig in series.figures) {
      if (fig.isSecret && snap.trackedOrDefault(fig.id).owned) {
        return true;
      }
    }
  }
  return false;
}
