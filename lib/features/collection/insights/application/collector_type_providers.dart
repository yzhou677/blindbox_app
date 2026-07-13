import 'package:blindbox_app/features/catalog/application/catalog_bundle_provider.dart';
import 'package:blindbox_app/features/collection/application/collection_notifier.dart';
import 'package:blindbox_app/features/collection/application/shelf_emotional_providers.dart';
import 'package:blindbox_app/features/collection/data/collection_memory_store.dart';
import 'package:blindbox_app/features/collection/insights/application/collector_journey_summary.dart';
import 'package:blindbox_app/features/collection/insights/application/collector_type_display_stats.dart';
import 'package:blindbox_app/features/collection/insights/application/collector_type_needs_reveal.dart';
import 'package:blindbox_app/features/collection/insights/application/collector_type_resolver.dart';
import 'package:blindbox_app/features/collection/insights/application/collector_type_view_model.dart';
import 'package:blindbox_app/features/collection/insights/domain/collector_type_archetype.dart';
import 'package:blindbox_app/features/collection/insights/domain/collector_type_identity.dart';
import 'package:blindbox_app/features/collection/insights/domain/collector_type_resolution.dart';
import 'package:blindbox_app/features/collection/insights/domain/collector_type_reveal_record.dart';
import 'package:blindbox_app/features/collection/insights/domain/collector_type_stats.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Last **revealed** Collector Type — persisted snapshot for Hero / dashboard.
///
/// Never the live candidate. Updates after Reveal persists (watches ViewModel).
/// Identity fields are frozen; use [collectorTypeDisplayStatsProvider] for
/// At a Glance / Shelf Progress numbers (may live-derive when stats schema is old).
final collectorTypeIdentityProvider = Provider<CollectorTypeIdentity?>((ref) {
  ref.watch(collectionMemoryBootstrapProvider);
  // Rebuild when a reveal writes a new snapshot to the memory store.
  ref.watch(collectorTypeViewModelProvider);
  return CollectionMemoryStore.instance.cachedCollectorTypeIdentity;
});

/// Stats for Insights numbers — frozen when schema current, else live-derived.
///
/// Does **not** rewrite prefs. Identity (type / reason / signature) stays frozen.
final collectorTypeDisplayStatsProvider = Provider<CollectorTypeStats?>((ref) {
  final identity = ref.watch(collectorTypeIdentityProvider);
  if (identity == null) return null;
  final snap = ref.watch(collectionNotifierProvider);
  final profile = ref.watch(shelfEmotionalProfileProvider);
  final catalog = ref.watch(catalogBundleProvider).valueOrNull;
  ref.watch(collectionMemoryBootstrapProvider);
  ref.watch(collectorTypeViewModelProvider);
  final memory = CollectionMemoryStore.instance.cached;
  return resolveCollectorTypeDisplayStats(
    storedIdentity: identity,
    memory: memory,
    snapshot: snap,
    profile: profile,
    catalog: catalog,
  );
});

/// Live resolve of the current shelf — transient candidate, never persisted.
///
/// Recomputes whenever collection (or catalog / emotional profile) changes.
/// Does **not** overwrite SharedPreferences identity.
final collectorTypeLiveResolutionProvider =
    Provider<CollectorTypeResolution>((ref) {
  final snap = ref.watch(collectionNotifierProvider);
  final profile = ref.watch(shelfEmotionalProfileProvider);
  final catalog = ref.watch(catalogBundleProvider).valueOrNull;
  return resolveCollectorType(
    snapshot: snap,
    profile: profile,
    catalog: catalog,
  );
});

/// Live candidate archetype id (convenience for affordances / tests).
final collectorTypeCandidateArchetypeProvider =
    Provider<CollectorTypeArchetypeId>((ref) {
  return ref.watch(collectorTypeLiveResolutionProvider).archetypeId;
});

/// Whether Insights should encourage another Reveal.
///
/// True when shelf **signature**, **resolverVersion**, or **stats schema**
/// drifted vs last reveal (**When** only — does not decide the reveal result).
final collectorTypeNeedsRevealProvider = Provider<bool>((ref) {
  ref.watch(collectionMemoryBootstrapProvider);
  // Recompute after reveal persists.
  ref.watch(collectorTypeViewModelProvider);
  final live = ref.watch(collectorTypeLiveResolutionProvider);
  final cached = CollectionMemoryStore.instance.cached;
  final hasRevealed =
      (cached.collectorTypeArchetypeId?.isNotEmpty ?? false) &&
      cached.collectorTypeRevealedAtMs != null;

  return computeCollectorTypeNeedsReveal(
    hasRevealed: hasRevealed,
    persistedSignatureHash: cached.collectorTypeSignatureHash,
    persistedResolverVersion: cached.revealedResolverVersion,
    liveCandidate: live,
    currentResolverVersion: kCollectorTypeResolverVersion,
    persistedStatsAreCurrent: memoryCollectorTypeStatsAreCurrent(cached),
  );
});

/// Whether the shelf signature drifted and an era transition was recorded.
final collectorTypeEvolutionHintProvider = Provider<bool>((ref) {
  final snap = ref.watch(collectionNotifierProvider);
  ref.watch(collectionMemoryBootstrapProvider);
  ref.watch(collectorTypeViewModelProvider);
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

/// Live Collector Journey summary — watches the shelf + memory, not reveal stats.
///
/// Collector Journey is intentionally LIVE.
/// Unlike Collector Type and other insight cards,
/// Journey reflects the user's evolving collection history
/// and is not part of the Reveal snapshot.
final collectorJourneySummaryProvider = Provider<CollectorJourneySummary>((
  ref,
) {
  final snapshot = ref.watch(collectionNotifierProvider);
  ref.watch(collectionMemoryBootstrapProvider);
  final memory = CollectionMemoryStore.instance.cached;
  return buildCollectorJourneySummary(memory: memory, snapshot: snapshot);
});
