import 'package:blindbox_app/features/catalog/application/catalog_bundle_provider.dart';
import 'package:blindbox_app/features/collection/application/collection_notifier.dart';
import 'package:blindbox_app/features/collection/application/shelf_emotional_providers.dart';
import 'package:blindbox_app/features/collection/application/shelf_emotional_interpreter.dart';
import 'package:blindbox_app/features/collection/data/collection_memory_store.dart';
import 'package:blindbox_app/features/collection/insights/application/collector_type_resolver.dart';
import 'package:blindbox_app/features/collection/insights/domain/collector_type_reveal_stage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

export 'package:blindbox_app/features/collection/insights/domain/collector_type_reveal_stage.dart';

/// Orchestrates the manual reveal flow (stable identity until re-reveal).
final class CollectorTypeViewModel extends Notifier<CollectorTypeRevealStage> {
  @override
  CollectorTypeRevealStage build() {
    // Read-only: watching the bootstrap future would reset mid-reveal when it completes.
    ref.read(collectionMemoryBootstrapProvider);
    final cached = CollectionMemoryStore.instance.cached.collectorTypeIdentity;
    return CollectorTypeRevealIdle(cachedIdentity: cached);
  }

  Future<void> requestReveal() async {
    if (state is CollectorTypeRevealAnalyzing) return;

    state = const CollectorTypeRevealAnalyzing();
    final started = DateTime.now();

    final snap = ref.read(collectionNotifierProvider);
    final catalog = ref.read(catalogBundleProvider).valueOrNull;
    final profile = interpretShelf(snap);

    await CollectionMemoryStore.instance.ensureLoaded();
    final memory = CollectionMemoryStore.instance.cached;

    final identity = resolveCollectorType(
      snapshot: snap,
      profile: profile,
      catalog: catalog,
      memory: memory,
    );

    await CollectionMemoryStore.instance.saveCollectorType(identity);

    final elapsed = DateTime.now().difference(started);
    final remaining = Duration(milliseconds: collectorTypeAnalyzingHoldMs) -
        elapsed;
    if (remaining > Duration.zero) {
      await Future<void>.delayed(remaining);
    }

    state = CollectorTypeRevealRevealed(identity);
  }

  void showCached() {
    final cached = CollectionMemoryStore.instance.cached.collectorTypeIdentity;
    if (cached != null) {
      state = CollectorTypeRevealRevealed(cached);
    } else {
      state = const CollectorTypeRevealIdle();
    }
  }

  void resetToIdle() {
    final cached = CollectionMemoryStore.instance.cached.collectorTypeIdentity;
    state = CollectorTypeRevealIdle(cachedIdentity: cached);
  }
}
