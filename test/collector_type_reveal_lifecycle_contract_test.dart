import 'package:blindbox_app/features/catalog/application/catalog_bundle_provider.dart';
import 'package:blindbox_app/features/catalog/catalog_bundle.dart';
import 'package:blindbox_app/features/collection/application/collection_notifier.dart';
import 'package:blindbox_app/features/collection/application/shelf_emotional_interpreter.dart';
import 'package:blindbox_app/features/collection/data/collection_memory_store.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/collection/insights/application/collector_type_needs_reveal.dart';
import 'package:blindbox_app/features/collection/insights/application/collector_type_providers.dart';
import 'package:blindbox_app/features/collection/insights/application/collector_type_resolver.dart';
import 'package:blindbox_app/features/collection/insights/application/collector_type_view_model.dart';
import 'package:blindbox_app/features/collection/insights/domain/collector_type_archetype.dart';
import 'package:blindbox_app/features/collection/insights/domain/collector_type_identity.dart';
import 'package:blindbox_app/features/collection/insights/domain/collector_type_reason_key.dart';
import 'package:blindbox_app/features/collection/insights/domain/collector_type_reveal_record.dart';
import 'package:blindbox_app/features/collection/insights/domain/collector_type_reveal_stage.dart';
import 'package:blindbox_app/features/collection/insights/domain/collector_type_stats.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/collection_fixtures.dart';

/// 5.2 reveal lifecycle contract: invalidation ??identity result.
final class _SnapNotifier extends CollectionNotifier {
  _SnapNotifier(this._snap);
  final CollectionSnapshot _snap;

  @override
  CollectionSnapshot build() => _snap;
}

const _emptyCatalog = CatalogSeedBundle(
  brands: [],
  ips: [],
  series: [],
  figures: [],
);

CollectorTypeStats get _emptyStats => const CollectorTypeStats(
      totalOwned: 0,
      totalWishlist: 0,
      trackedSeries: 0,
      completedSeriesCount: 0,
      masterCompleteSeriesCount: 0,
      masterEligibleSeriesCount: 0,
      completionPercent: 0,
      secretOwned: 0,
      secretSlots: 0,
      brandBreakdown: {},
      topSeries: [],
      customSeriesRatio: 0,
    );

Future<void> _persistIdentity({
  required CollectorTypeArchetypeId archetypeId,
  required String signatureHash,
  String resolverVersion = kCollectorTypeResolverVersion,
  DateTime? revealedAt,
}) async {
  final at = revealedAt ?? DateTime(2026, 1, 1);
  final identity = CollectorTypeIdentity(
    archetypeId: archetypeId,
    revealedAt: at,
    signatureHash: signatureHash,
    stats: _emptyStats,
    reasonKey: CollectorTypeReasonKey.curiousSpread,
  );
  await CollectionMemoryStore.instance.saveCollectorType(
    identity,
    revealRecord: CollectorTypeRevealRecord(
      archetypeId: archetypeId,
      revealedAt: at,
      signatureHash: signatureHash,
      reasonKey: CollectorTypeReasonKey.curiousSpread,
      score: 50,
      confidence: 0.3,
      resolverVersion: resolverVersion,
      isEvolution: false,
    ),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    CollectionMemoryStore.instance.resetForTest();
  });

  test(
    '1. needsReveal (signature drift) ??Reveal persists resolver interpretation',
    () async {
      final priorSnap = CollectionSnapshot(
        shelfSeries: [testShelfSeries(id: 'old', catalogTemplateId: 'old_t')],
        figureStates: const {},
      );
      await _persistIdentity(
        archetypeId: CollectorTypeArchetypeId.wanderer,
        signatureHash: computeCollectorTypeSignatureHash(priorSnap),
      );

      // Multi-IP incomplete shelf ??Loyalist/Wanderer shape (not wanderer-only empty).
      final nextSnap = CollectionSnapshot(
        shelfSeries: [
          testShelfSeries(
            id: 's1',
            name: 'A',
            taxonomyIpId: 'smiski',
            taxonomyBrandId: 'dreams',
            brand: 'Dreams',
            catalogTemplateId: 'c1',
            figures: const [
              ShelfFigure(
                id: 'f1',
                seriesId: 's1',
                name: 'A1',
                rarity: 'Regular',
                isSecret: false,
              ),
            ],
          ),
          testShelfSeries(
            id: 's2',
            name: 'B',
            taxonomyIpId: 'hirono',
            taxonomyBrandId: 'pop_mart',
            brand: 'POP MART',
            catalogTemplateId: 'c2',
            figures: const [
              ShelfFigure(
                id: 'f2',
                seriesId: 's2',
                name: 'B1',
                rarity: 'Regular',
                isSecret: false,
              ),
            ],
          ),
          testShelfSeries(
            id: 's3',
            name: 'C',
            taxonomyIpId: 'dimoo',
            taxonomyBrandId: 'pop_mart',
            brand: 'POP MART',
            catalogTemplateId: 'c3',
            figures: const [
              ShelfFigure(
                id: 'f3',
                seriesId: 's3',
                name: 'C1',
                rarity: 'Regular',
                isSecret: false,
              ),
            ],
          ),
        ],
        figureStates: const {},
      );
      final live = resolveCollectorType(
        snapshot: nextSnap,
        profile: interpretShelf(nextSnap),
      );
      expect(live.archetypeId, isNot(CollectorTypeArchetypeId.wanderer));

      expect(
        computeCollectorTypeNeedsReveal(
          hasRevealed: true,
          persistedSignatureHash: computeCollectorTypeSignatureHash(priorSnap),
          persistedResolverVersion: kCollectorTypeResolverVersion,
          liveCandidate: live,
        ),
        isTrue,
      );

      final container = ProviderContainer(
        overrides: [
          collectionNotifierProvider.overrideWith(() => _SnapNotifier(nextSnap)),
          catalogBundleProvider.overrideWith((ref) async => _emptyCatalog),
        ],
      );
      addTearDown(container.dispose);

      container.read(collectorTypeViewModelProvider);
      expect(container.read(collectorTypeNeedsRevealProvider), isTrue);

      await container.read(collectorTypeViewModelProvider.notifier).requestReveal();

      final revealed = container.read(collectorTypeViewModelProvider)
          as CollectorTypeRevealRevealed;
      expect(revealed.identity.archetypeId, live.archetypeId);
      expect(
        CollectionMemoryStore.instance.cachedCollectorTypeIdentity!.archetypeId,
        live.archetypeId,
      );
      expect(container.read(collectorTypeNeedsRevealProvider), isFalse);
      expect(
        CollectionMemoryStore.instance.cached.collectorTypeRevealHistory,
        isNotEmpty,
      );
    },
  );

  test(
    '2. needsReveal + resolver still previous archetype ??identity stays',
    () async {
      final snap = CollectionSnapshot(
        shelfSeries: [testShelfSeries()],
        figureStates: const {},
      );
      final live = resolveCollectorType(
        snapshot: snap,
        profile: interpretShelf(snap),
      );
      await _persistIdentity(
        archetypeId: live.archetypeId,
        signatureHash: 'stale-other-sig',
      );

      final container = ProviderContainer(
        overrides: [
          collectionNotifierProvider.overrideWith(() => _SnapNotifier(snap)),
          catalogBundleProvider.overrideWith((ref) async => _emptyCatalog),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(collectorTypeNeedsRevealProvider), isTrue);
      await container.read(collectorTypeViewModelProvider.notifier).requestReveal();

      final revealed = container.read(collectorTypeViewModelProvider)
          as CollectorTypeRevealRevealed;
      expect(revealed.identity.archetypeId, live.archetypeId);
    },
  );

  test(
    '3. sameSignature does not block needsReveal reinterpretation (version)',
    () async {
      final snap = CollectionSnapshot(
        shelfSeries: [
          testShelfSeries(
            id: 's1',
            taxonomyIpId: 'smiski',
            taxonomyBrandId: 'dreams',
            brand: 'Dreams',
            catalogTemplateId: 'c1',
            figures: const [
              ShelfFigure(
                id: 'a',
                seriesId: 's1',
                name: 'A',
                rarity: 'Regular',
                isSecret: false,
              ),
              ShelfFigure(
                id: 'b',
                seriesId: 's1',
                name: 'B',
                rarity: 'Regular',
                isSecret: false,
              ),
            ],
          ),
          testShelfSeries(
            id: 's2',
            taxonomyIpId: 'smiski',
            taxonomyBrandId: 'dreams',
            brand: 'Dreams',
            catalogTemplateId: 'c2',
            figures: const [
              ShelfFigure(
                id: 'c',
                seriesId: 's2',
                name: 'C',
                rarity: 'Regular',
                isSecret: false,
              ),
            ],
          ),
          testShelfSeries(
            id: 's3',
            taxonomyIpId: 'smiski',
            taxonomyBrandId: 'dreams',
            brand: 'Dreams',
            catalogTemplateId: 'c3',
            figures: const [
              ShelfFigure(
                id: 'd',
                seriesId: 's3',
                name: 'D',
                rarity: 'Regular',
                isSecret: false,
              ),
            ],
          ),
        ],
        figureStates: const {},
      );
      final live = resolveCollectorType(
        snapshot: snap,
        profile: interpretShelf(snap),
      );
      expect(live.archetypeId, CollectorTypeArchetypeId.loyalist);

      // Same signature as live, but old resolver version ??needsReveal.
      await _persistIdentity(
        archetypeId: CollectorTypeArchetypeId.wanderer,
        signatureHash: live.signatureHash,
        resolverVersion: '5.1',
      );

      expect(
        computeCollectorTypeNeedsReveal(
          hasRevealed: true,
          persistedSignatureHash: live.signatureHash,
          persistedResolverVersion: '5.1',
          liveCandidate: live,
        ),
        isTrue,
      );

      final container = ProviderContainer(
        overrides: [
          collectionNotifierProvider.overrideWith(() => _SnapNotifier(snap)),
          catalogBundleProvider.overrideWith((ref) async => _emptyCatalog),
        ],
      );
      addTearDown(container.dispose);

      await container.read(collectorTypeViewModelProvider.notifier).requestReveal();

      final revealed = container.read(collectorTypeViewModelProvider)
          as CollectorTypeRevealRevealed;
      expect(revealed.identity.archetypeId, CollectorTypeArchetypeId.loyalist);
      expect(
        CollectionMemoryStore.instance.cached.revealedResolverVersion,
        kCollectorTypeResolverVersion,
      );
    },
  );

  test(
    '4. repeated Reveal while needsReveal==false does not churn identity',
    () async {
      final snap = CollectionSnapshot(
        shelfSeries: [
          testShelfSeries(
            id: 's1',
            taxonomyIpId: 'smiski',
            taxonomyBrandId: 'dreams',
            brand: 'Dreams',
            catalogTemplateId: 'c1',
            figures: const [
              ShelfFigure(
                id: 'a',
                seriesId: 's1',
                name: 'A',
                rarity: 'Regular',
                isSecret: false,
              ),
            ],
          ),
          testShelfSeries(
            id: 's2',
            taxonomyIpId: 'hirono',
            taxonomyBrandId: 'pop_mart',
            brand: 'POP MART',
            catalogTemplateId: 'c2',
            figures: const [
              ShelfFigure(
                id: 'b',
                seriesId: 's2',
                name: 'B',
                rarity: 'Regular',
                isSecret: false,
              ),
            ],
          ),
          testShelfSeries(
            id: 's3',
            taxonomyIpId: 'dimoo',
            taxonomyBrandId: 'pop_mart',
            brand: 'POP MART',
            catalogTemplateId: 'c3',
            figures: const [
              ShelfFigure(
                id: 'c',
                seriesId: 's3',
                name: 'C',
                rarity: 'Regular',
                isSecret: false,
              ),
            ],
          ),
        ],
        figureStates: const {},
      );
      final live = resolveCollectorType(
        snapshot: snap,
        profile: interpretShelf(snap),
      );
      // Persist a *different* title with the *same* live signature + current version
      // (simulates a Still that already consumed invalidation under old policy).
      expect(live.archetypeId, isNot(CollectorTypeArchetypeId.wanderer));
      await _persistIdentity(
        archetypeId: CollectorTypeArchetypeId.wanderer,
        signatureHash: live.signatureHash,
        revealedAt: DateTime(2026, 7, 1),
      );

      final container = ProviderContainer(
        overrides: [
          collectionNotifierProvider.overrideWith(() => _SnapNotifier(snap)),
          catalogBundleProvider.overrideWith((ref) async => _emptyCatalog),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(collectorTypeNeedsRevealProvider), isFalse);

      await container.read(collectorTypeViewModelProvider.notifier).requestReveal();

      final revealed = container.read(collectorTypeViewModelProvider)
          as CollectorTypeRevealRevealed;
      // Unchanged shelf: sameSignature Still keeps wanderer (no churn to live).
      expect(revealed.identity.archetypeId, CollectorTypeArchetypeId.wanderer);
      expect(container.read(collectorTypeNeedsRevealProvider), isFalse);
    },
  );

  test('5. reveal history still appends on needsReveal reinterpretation',
      () async {
    final snap = CollectionSnapshot(
      shelfSeries: [testShelfSeries()],
      figureStates: const {},
    );
    await _persistIdentity(
      archetypeId: CollectorTypeArchetypeId.wanderer,
      signatureHash: 'old',
    );
    final before =
        CollectionMemoryStore.instance.cached.collectorTypeRevealHistory.length;

    final container = ProviderContainer(
      overrides: [
        collectionNotifierProvider.overrideWith(() => _SnapNotifier(snap)),
        catalogBundleProvider.overrideWith((ref) async => _emptyCatalog),
      ],
    );
    addTearDown(container.dispose);

    await container.read(collectorTypeViewModelProvider.notifier).requestReveal();

    final history =
        CollectionMemoryStore.instance.cached.collectorTypeRevealHistory;
    expect(history.length, before + 1);
    expect(history.last.resolverVersion, kCollectorTypeResolverVersion);
    expect(history.last.signatureHash, isNot('old'));
  });
}
