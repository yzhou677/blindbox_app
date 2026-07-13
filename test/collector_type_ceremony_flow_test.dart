import 'package:blindbox_app/features/catalog/application/catalog_bundle_provider.dart';
import 'package:blindbox_app/features/catalog/catalog_bundle.dart';
import 'package:blindbox_app/features/collection/application/collection_notifier.dart';
import 'package:blindbox_app/features/collection/application/shelf_emotional_interpreter.dart';
import 'package:blindbox_app/features/collection/data/collection_memory_store.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/collection/insights/application/collector_type_ceremony.dart';
import 'package:blindbox_app/features/collection/insights/application/collector_type_providers.dart';
import 'package:blindbox_app/features/collection/insights/application/collector_type_resolver.dart';
import 'package:blindbox_app/features/collection/insights/domain/collector_type_archetype.dart';
import 'package:blindbox_app/features/collection/insights/domain/collector_type_identity.dart';
import 'package:blindbox_app/features/collection/insights/domain/collector_type_reveal_stage.dart';
import 'package:blindbox_app/features/collection/insights/domain/collector_type_stats.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/collection_fixtures.dart';

final class _SnapNotifier extends CollectionNotifier {
  _SnapNotifier(this._snap);
  final CollectionSnapshot _snap;

  @override
  CollectionSnapshot build() => _snap;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    CollectionMemoryStore.instance.resetForTest();
  });

  final emptyCatalog = const CatalogSeedBundle(
    brands: [],
    ips: [],
    series: [],
    figures: [],
  );

  test('first reveal enqueues first-reveal ceremony event', () async {
    final snap = CollectionSnapshot(
      shelfSeries: [testShelfSeries()],
      figureStates: const {},
    );
    final container = ProviderContainer(
      overrides: [
        collectionNotifierProvider.overrideWith(() => _SnapNotifier(snap)),
        catalogBundleProvider.overrideWith((ref) async => emptyCatalog),
      ],
    );
    addTearDown(container.dispose);

    expect(container.read(collectorTypeCeremonyProvider), isNull);

    await container.read(collectorTypeViewModelProvider.notifier).requestReveal();

    final event = container.read(collectorTypeCeremonyProvider);
    expect(event, isNotNull);
    expect(event!.isFirstReveal, isTrue);
    expect(
      container.read(collectorTypeViewModelProvider),
      isA<CollectorTypeRevealRevealed>(),
    );
  });

  test('same-type re-reveal skips ceremony event', () async {
    final snap = CollectionSnapshot(
      shelfSeries: [testShelfSeries()],
      figureStates: const {},
    );
    final signature = computeCollectorTypeSignatureHash(snap);
    final identity = resolveCollectorType(
      snapshot: snap,
      profile: interpretShelf(snap),
      revealedAt: DateTime(2026, 1, 1),
    );
    await CollectionMemoryStore.instance.saveCollectorType(
      CollectorTypeIdentity(
        archetypeId: identity.archetypeId,
        revealedAt: DateTime(2026, 1, 1),
        signatureHash: signature,
        stats: identity.stats,
        reasonKey: identity.reasonKey,
      ),
    );

    final container = ProviderContainer(
      overrides: [
        collectionNotifierProvider.overrideWith(() => _SnapNotifier(snap)),
        catalogBundleProvider.overrideWith((ref) async => emptyCatalog),
      ],
    );
    addTearDown(container.dispose);

    container.read(collectorTypeViewModelProvider);
    expect(container.read(collectorTypeCeremonyProvider), isNull);

    await container.read(collectorTypeViewModelProvider.notifier).requestReveal();

    expect(container.read(collectorTypeCeremonyProvider), isNull);
  });

  test('archetype change enqueues evolved ceremony when gate allows', () async {
    final snap = CollectionSnapshot(
      shelfSeries: [testShelfSeries()],
      figureStates: const {},
    );
    await CollectionMemoryStore.instance.saveCollectorType(
      CollectorTypeIdentity(
        // Intentionally different from resolver outcome for this shelf.
        archetypeId: CollectorTypeArchetypeId.worldbuilder,
        revealedAt: DateTime(2026, 1, 1),
        // Different signature so the evolution gate may consider a type change.
        signatureHash: 'prior-signature',
        stats: const CollectorTypeStats(
          totalOwned: 0,
          totalWishlist: 0,
          trackedSeries: 1,
          completedSeriesCount: 0,
          masterCompleteSeriesCount: 0,
          masterEligibleSeriesCount: 0,
          completionPercent: 0,
          secretOwned: 0,
          secretSlots: 0,
          brandBreakdown: {'POP MART': 1},
          topSeries: [],
          customSeriesRatio: 0,
        ),
      ),
    );

    final container = ProviderContainer(
      overrides: [
        collectionNotifierProvider.overrideWith(() => _SnapNotifier(snap)),
        catalogBundleProvider.overrideWith((ref) async => emptyCatalog),
      ],
    );
    addTearDown(container.dispose);

    container.read(collectorTypeViewModelProvider);
    await container.read(collectorTypeViewModelProvider.notifier).requestReveal();

    final event = container.read(collectorTypeCeremonyProvider);
    final revealed = container.read(collectorTypeViewModelProvider)
        as CollectorTypeRevealRevealed;
    // needsReveal (stale signature) ??always persist resolver candidate.
    expect(revealed.identity.archetypeId, isNot(CollectorTypeArchetypeId.worldbuilder));
    expect(event, isNotNull);
    expect(event!.isFirstReveal, isFalse);
    expect(event.identity.archetypeId, revealed.identity.archetypeId);
  });
}
