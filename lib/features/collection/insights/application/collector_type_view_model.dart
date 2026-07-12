import 'package:blindbox_app/features/catalog/application/catalog_bundle_provider.dart';
import 'package:blindbox_app/features/collection/application/collection_notifier.dart';
import 'package:blindbox_app/features/collection/application/shelf_emotional_providers.dart';
import 'package:blindbox_app/features/collection/application/shelf_emotional_interpreter.dart';
import 'package:blindbox_app/features/collection/data/collection_memory_store.dart';
import 'package:blindbox_app/features/collection/insights/application/collector_type_ceremony.dart';
import 'package:blindbox_app/features/collection/insights/application/collector_type_evolution_gate.dart';
import 'package:blindbox_app/features/collection/insights/application/collector_type_needs_reveal.dart';
import 'package:blindbox_app/features/collection/insights/application/collector_type_resolver.dart';
import 'package:blindbox_app/features/collection/insights/domain/collector_type_identity.dart';
import 'package:blindbox_app/features/collection/insights/domain/collector_type_reason_resolve.dart';
import 'package:blindbox_app/features/collection/insights/domain/collector_type_reveal_record.dart';
import 'package:blindbox_app/features/collection/insights/domain/collector_type_reveal_stage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

export 'package:blindbox_app/features/collection/insights/domain/collector_type_reveal_stage.dart';

/// Orchestrates the manual reveal flow (stable identity until re-reveal).
///
/// **Lifecycle contract (5.2+):**
/// - [computeCollectorTypeNeedsReveal] / signature — **When** a reveal is needed
/// - [resolveCollectorType] — **What** the current shelf is
/// - [shouldEvolve] — **How** to present change on an *unchanged* shelf only
///   (`needsReveal == false`); never overrides a `needsReveal` reinterpretation
///
/// Hero displays last revealed identity. Live scoring is
/// [collectorTypeLiveResolutionProvider] (never auto-persisted).
final class CollectorTypeViewModel extends Notifier<CollectorTypeRevealStage> {
  @override
  CollectorTypeRevealStage build() {
    // Read-only: watching the bootstrap future would reset mid-reveal when it completes.
    ref.read(collectionMemoryBootstrapProvider);
    final cached =
        CollectionMemoryStore.instance.cachedCollectorTypeIdentity?.healed();
    if (cached != null) {
      return CollectorTypeRevealRevealed(cached);
    }
    return const CollectorTypeRevealIdle();
  }

  Future<void> requestReveal() async {
    if (state is CollectorTypeRevealAnalyzing) return;

    final prior = CollectionMemoryStore.instance.cachedCollectorTypeIdentity;
    final priorVersion =
        CollectionMemoryStore.instance.cached.revealedResolverVersion;
    final isFirstReveal = prior == null;

    final snap = ref.read(collectionNotifierProvider);
    final catalog = ref.read(catalogBundleProvider).valueOrNull;
    final profile = interpretShelf(snap);

    // Capture invalidation *before* analyzing work; signature's job ends here.
    final liveForInvalidation = resolveCollectorType(
      snapshot: snap,
      profile: profile,
      catalog: catalog,
    );
    final needsReveal = isFirstReveal ||
        computeCollectorTypeNeedsReveal(
          hasRevealed: true,
          persistedSignatureHash: prior.signatureHash,
          persistedResolverVersion: priorVersion,
          liveCandidate: liveForInvalidation,
        );

    state = const CollectorTypeRevealAnalyzing();
    final started = DateTime.now();
    // Yield one frame so the analyzing UI paints before heavy sync scoring work.
    await Future<void>.delayed(Duration.zero);
    if (state is! CollectorTypeRevealAnalyzing) return;

    await CollectionMemoryStore.instance.ensureLoaded();
    if (state is! CollectorTypeRevealAnalyzing) return;
    final revealedAt = DateTime.now();

    // Identity scores from current shelf only — no Journey memory input.
    final challenger = resolveCollectorType(
      snapshot: snap,
      profile: profile,
      catalog: catalog,
      revealedAt: revealedAt,
    );

    // needsReveal / first reveal: resolver is sole authority over identity.
    // Unchanged shelf (!needsReveal): evolution gate may Still (incl. sameSignature).
    final bool takeCandidate;
    if (prior == null || needsReveal) {
      takeCandidate = true;
    } else {
      takeCandidate = shouldEvolve(
        previous: prior,
        challenger: challenger,
        snapshot: snap,
        now: revealedAt,
        previousResolverVersion: priorVersion,
      );
    }

    final candidateId = challenger.archetypeId;
    final keptId = takeCandidate ? null : prior!.archetypeId;

    final CollectorTypeIdentity identity;
    if (takeCandidate) {
      identity = CollectorTypeIdentity(
        archetypeId: candidateId,
        revealedAt: revealedAt,
        signatureHash: challenger.signatureHash,
        stats: challenger.stats,
        reasonKey: effectiveReasonKey(
          archetypeId: candidateId,
          reasonKey: challenger.reasonKey,
        ),
      );
    } else {
      // Still (unchanged shelf only): keep title; refresh stats/signature/reason.
      identity = CollectorTypeIdentity(
        archetypeId: keptId!,
        revealedAt: revealedAt,
        signatureHash: challenger.signatureHash,
        stats: challenger.stats,
        reasonKey: challenger.reasonKeyFor(keptId),
      );
    }

    final typeChanged =
        prior != null && prior.archetypeId != identity.archetypeId;
    await CollectionMemoryStore.instance.saveCollectorType(
      identity,
      revealRecord: CollectorTypeRevealRecord.fromResolvePass(
        identity: identity,
        resolution: challenger,
        isEvolution: typeChanged,
      ),
    );

    if (state is! CollectorTypeRevealAnalyzing) return;

    final elapsed = DateTime.now().difference(started);
    final remaining = Duration(milliseconds: collectorTypeAnalyzingHoldMs) -
        elapsed;
    if (remaining > Duration.zero) {
      await Future<void>.delayed(remaining);
      if (state is! CollectorTypeRevealAnalyzing) return;
    }

    // Persistent Insights state settles on the hero card immediately.
    state = CollectorTypeRevealRevealed(identity);

    if (isFirstReveal || typeChanged) {
      ref.read(collectorTypeCeremonyProvider.notifier).present(
            identity: identity,
            isFirstReveal: isFirstReveal,
          );
    }
  }

  void showCached() {
    final cached = CollectionMemoryStore.instance.cachedCollectorTypeIdentity;
    if (cached != null) {
      state = CollectorTypeRevealRevealed(cached);
    } else {
      state = const CollectorTypeRevealIdle();
    }
  }

  void resetToIdle() {
    showCached();
  }
}
