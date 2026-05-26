import 'package:blindbox_app/features/collection/application/collection_notifier.dart';
import 'package:blindbox_app/features/collection/application/shelf_emotional_providers.dart';
import 'package:blindbox_app/features/collection/data/collection_memory_store.dart';
import 'package:blindbox_app/features/collection/insights/application/collector_type_resolver.dart';
import 'package:blindbox_app/features/collection/insights/application/collector_type_view_model.dart';
import 'package:blindbox_app/features/collection/insights/domain/collector_type_identity.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Cached collector identity from local memory store.
final collectorTypeIdentityProvider = Provider<CollectorTypeIdentity?>((ref) {
  ref.watch(collectionMemoryBootstrapProvider);
  return CollectionMemoryStore.instance.cached.collectorTypeIdentity;
});

/// Whether the shelf signature drifted and an era transition was recorded.
final collectorTypeEvolutionHintProvider = Provider<bool>((ref) {
  ref.watch(collectionNotifierProvider);
  ref.watch(collectionMemoryBootstrapProvider);
  final cached = CollectionMemoryStore.instance.cached;
  final identity = cached.collectorTypeIdentity;
  if (identity == null) return false;

  final snap = ref.read(collectionNotifierProvider);
  final liveHash = computeCollectorTypeSignatureHash(snap);
  if (liveHash == identity.signatureHash) return false;

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
