import 'package:blindbox_app/features/collection/application/collection_notifier.dart';
import 'package:blindbox_app/features/collection/application/shelf_emotional_providers.dart';
import 'package:blindbox_app/features/collection/data/collection_memory_store.dart';
import 'package:blindbox_app/features/collection/insights/application/collector_journey_summary.dart';
import 'package:blindbox_app/features/collection/insights/application/collector_type_resolver.dart';
import 'package:blindbox_app/features/collection/insights/application/collector_type_view_model.dart';
import 'package:blindbox_app/features/collection/insights/domain/collector_type_identity.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Cached collector identity from local memory store.
final collectorTypeIdentityProvider = Provider<CollectorTypeIdentity?>((ref) {
  ref.watch(collectionMemoryBootstrapProvider);
  return CollectionMemoryStore.instance.cachedCollectorTypeIdentity;
});

/// Whether the shelf signature drifted and an era transition was recorded.
final collectorTypeEvolutionHintProvider = Provider<bool>((ref) {
  final snap = ref.watch(collectionNotifierProvider);
  ref.watch(collectionMemoryBootstrapProvider);
  final cached = CollectionMemoryStore.instance.cached;
  final hasRevealed =
      (cached.collectorTypeArchetypeId?.isNotEmpty ?? false) &&
      cached.collectorTypeRevealedAtMs != null;
  if (!hasRevealed) return false;
  final storedHash = cached.collectorTypeSignatureHash;
  if (storedHash == null || storedHash.isEmpty) return false;

  final liveHash = computeCollectorTypeSignatureHash(snap);
  if (liveHash == storedHash) return false;

  final prior = cached.priorEraForEvolution;
  final current = cached.lastRecordedEra;
  if (prior == null || current == null) return false;
  return prior.shelfMood != current.shelfMood ||
      prior.dominantIpId != current.dominantIpId ||
      prior.seriesCount != current.seriesCount;
});

final collectorTypeViewModelProvider =
    NotifierProvider<CollectorTypeViewModel, CollectorTypeRevealStage>(
      CollectorTypeViewModel.new,
    );

final collectorJourneySummaryProvider = Provider<CollectorJourneySummary>((
  ref,
) {
  final snapshot = ref.watch(collectionNotifierProvider);
  ref.watch(collectionMemoryBootstrapProvider);
  final memory = CollectionMemoryStore.instance.cached;
  return buildCollectorJourneySummary(memory: memory, snapshot: snapshot);
});
