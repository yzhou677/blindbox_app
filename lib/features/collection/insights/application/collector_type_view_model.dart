import 'package:blindbox_app/features/catalog/application/catalog_bundle_provider.dart';
import 'package:blindbox_app/features/collection/application/collection_notifier.dart';
import 'package:blindbox_app/features/collection/application/shelf_emotional_providers.dart';
import 'package:blindbox_app/features/collection/application/shelf_emotional_interpreter.dart';
import 'package:blindbox_app/features/collection/data/collection_memory_store.dart';
import 'package:blindbox_app/features/collection/insights/application/collector_type_ceremony.dart';
import 'package:blindbox_app/features/collection/insights/application/collector_type_resolver.dart';
import 'package:blindbox_app/features/collection/insights/domain/collector_type_reveal_stage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

export 'package:blindbox_app/features/collection/insights/domain/collector_type_reveal_stage.dart';

/// Orchestrates the manual reveal flow (stable identity until re-reveal).
///
/// Durable UI state is idle / analyzing / revealed (hero card). The ceremonial
/// overlay is a separate one-shot event via [collectorTypeCeremonyProvider].
final class CollectorTypeViewModel extends Notifier<CollectorTypeRevealStage> {
  @override
  CollectorTypeRevealStage build() {
    // Read-only: watching the bootstrap future would reset mid-reveal when it completes.
    ref.read(collectionMemoryBootstrapProvider);
    final cached = CollectionMemoryStore.instance.cachedCollectorTypeIdentity;
    if (cached != null) {
      return CollectorTypeRevealRevealed(cached);
    }
    return const CollectorTypeRevealIdle();
  }

  Future<void> requestReveal() async {
    if (state is CollectorTypeRevealAnalyzing) return;

    final prior = CollectionMemoryStore.instance.cachedCollectorTypeIdentity;
    final isFirstReveal = prior == null;

    state = const CollectorTypeRevealAnalyzing();
    final started = DateTime.now();
    // Yield one frame so the analyzing UI paints before heavy sync scoring work.
    await Future<void>.delayed(Duration.zero);
    if (state is! CollectorTypeRevealAnalyzing) return;

    final snap = ref.read(collectionNotifierProvider);
    final catalog = ref.read(catalogBundleProvider).valueOrNull;
    final profile = interpretShelf(snap);

    await CollectionMemoryStore.instance.ensureLoaded();
    if (state is! CollectorTypeRevealAnalyzing) return;
    final memory = CollectionMemoryStore.instance.cached;

    final identity = resolveCollectorType(
      snapshot: snap,
      profile: profile,
      catalog: catalog,
      memory: memory,
    );

    await CollectionMemoryStore.instance.saveCollectorType(identity);
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

    final typeChanged =
        prior != null && prior.archetypeId != identity.archetypeId;
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
