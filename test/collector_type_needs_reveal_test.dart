import 'package:blindbox_app/features/catalog/application/catalog_bundle_provider.dart';
import 'package:blindbox_app/features/catalog/catalog_bundle.dart';
import 'package:blindbox_app/features/collection/application/collection_notifier.dart';
import 'package:blindbox_app/features/collection/application/shelf_emotional_interpreter.dart';
import 'package:blindbox_app/features/collection/data/collection_memory_store.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/collection/insights/application/collector_type_providers.dart';
import 'package:blindbox_app/features/collection/insights/application/collector_type_resolver.dart';
import 'package:blindbox_app/features/collection/insights/application/collector_type_view_model.dart';
import 'package:blindbox_app/features/collection/insights/domain/collector_type_archetype.dart';
import 'package:blindbox_app/features/collection/insights/domain/collector_type_identity.dart';
import 'package:blindbox_app/features/collection/insights/domain/collector_type_reason_key.dart';
import 'package:blindbox_app/features/collection/insights/domain/collector_type_reveal_record.dart';
import 'package:blindbox_app/features/collection/insights/domain/collector_type_stats.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/collection_fixtures.dart';

const _emptyCatalog = CatalogSeedBundle(
  brands: [],
  ips: [],
  series: [],
  figures: [],
);

final class NeedsRevealTestNotifier extends CollectionNotifier {
  NeedsRevealTestNotifier(this._snap);
  final CollectionSnapshot _snap;

  @override
  CollectionSnapshot build() => _snap;
}

List<Override> _overridesFor(CollectionSnapshot snap) => [
      collectionNotifierProvider.overrideWith(
        () => NeedsRevealTestNotifier(snap),
      ),
      catalogBundleProvider.overrideWith((ref) async => _emptyCatalog),
    ];

WishlistedCatalogSeries _wishlistedSeries(String id) => WishlistedCatalogSeries(
      catalogSeriesId: id,
      name: 'Wishlist $id',
      brand: 'POP MART',
      ipName: 'IP',
      imageKey: id,
      addedAtMicros: 1,
    );

Future<void> _saveRevealMatchingLive(CollectionSnapshot snap) async {
  final resolution = resolveCollectorType(
    snapshot: snap,
    profile: interpretShelf(snap),
    revealedAt: DateTime(2026, 1, 1),
  );
  await CollectionMemoryStore.instance.saveCollectorType(
    CollectorTypeIdentity(
      archetypeId: resolution.archetypeId,
      revealedAt: DateTime(2026, 1, 1),
      signatureHash: resolution.signatureHash,
      stats: resolution.stats,
      reasonKey: resolution.reasonKey,
    ),
    revealRecord: CollectorTypeRevealRecord.fromResolvePass(
      identity: CollectorTypeIdentity(
        archetypeId: resolution.archetypeId,
        revealedAt: DateTime(2026, 1, 1),
        signatureHash: resolution.signatureHash,
        stats: resolution.stats,
        reasonKey: resolution.reasonKey,
      ),
      resolution: resolution,
      isEvolution: false,
    ),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    CollectionMemoryStore.instance.resetForTest();
  });

  test('false when no persisted reveal', () async {
    final snap = CollectionSnapshot(
      shelfSeries: [testShelfSeries()],
      figureStates: const {},
    );
    final container = ProviderContainer(overrides: _overridesFor(snap));
    addTearDown(container.dispose);

    expect(container.read(collectorTypeNeedsRevealProvider), isFalse);
  });

  test('false when candidate matches last reveal under current version',
      () async {
    final snap = CollectionSnapshot(
      shelfSeries: [testShelfSeries()],
      figureStates: const {},
    );
    await _saveRevealMatchingLive(snap);

    final container = ProviderContainer(overrides: _overridesFor(snap));
    addTearDown(container.dispose);

    expect(container.read(collectorTypeNeedsRevealProvider), isFalse);
    expect(
      container.read(collectorTypeLiveResolutionProvider).archetypeId,
      CollectionMemoryStore.instance.cachedCollectorTypeIdentity!.archetypeId,
    );
  });

  test('true when stored signature differs from live shelf', () async {
    final snap = CollectionSnapshot(
      shelfSeries: [testShelfSeries()],
      figureStates: const {},
    );
    await CollectionMemoryStore.instance.saveCollectorType(
      CollectorTypeIdentity(
        archetypeId: CollectorTypeArchetypeId.wanderer,
        revealedAt: DateTime(2026, 1, 1),
        signatureHash: 'stale-signature',
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
          brandBreakdown: {},
          topSeries: [],
          customSeriesRatio: 0,
        ),
      ),
    );

    final container = ProviderContainer(overrides: _overridesFor(snap));
    addTearDown(container.dispose);

    expect(container.read(collectorTypeNeedsRevealProvider), isTrue);
  });

  test('true when only figure wishlist changes signature for Dreamer', () async {
    final series = testShelfSeries(
      figures: const [
        ShelfFigure(
          id: 'w1',
          seriesId: 'series_test',
          name: 'Wishlist A',
          rarity: 'Regular',
          isSecret: false,
        ),
        ShelfFigure(
          id: 'w2',
          seriesId: 'series_test',
          name: 'Wishlist B',
          rarity: 'Regular',
          isSecret: false,
        ),
      ],
    );
    final revealedSnap = CollectionSnapshot(
      shelfSeries: [series],
      figureStates: const {},
    );
    await _saveRevealMatchingLive(revealedSnap);

    final liveSnap = CollectionSnapshot(
      shelfSeries: [series],
      figureStates: const {
        'w1': TrackedFigure(
          figureId: 'w1',
          state: FigureCollectionState.wishlist,
        ),
        'w2': TrackedFigure(
          figureId: 'w2',
          state: FigureCollectionState.wishlist,
        ),
      },
    );
    final container = ProviderContainer(overrides: _overridesFor(liveSnap));
    addTearDown(container.dispose);

    expect(container.read(collectorTypeNeedsRevealProvider), isTrue);
  });

  test('true when only series wishlist changes signature for Dreamer', () async {
    await _saveRevealMatchingLive(CollectionSnapshot.emptyTest());

    final liveSnap = CollectionSnapshot(
      shelfSeries: const [],
      figureStates: const {},
      seriesWishlist: [
        _wishlistedSeries('wish_series_a'),
        _wishlistedSeries('wish_series_b'),
      ],
    );
    final container = ProviderContainer(overrides: _overridesFor(liveSnap));
    addTearDown(container.dispose);

    expect(container.read(collectorTypeNeedsRevealProvider), isTrue);
  });

  test('true when resolverVersion on reveal is outdated', () async {
    final snap = CollectionSnapshot(
      shelfSeries: [testShelfSeries()],
      figureStates: const {},
    );
    final resolution = resolveCollectorType(
      snapshot: snap,
      profile: interpretShelf(snap),
      revealedAt: DateTime(2026, 1, 1),
    );
    final identity = CollectorTypeIdentity(
      archetypeId: resolution.archetypeId,
      revealedAt: DateTime(2026, 1, 1),
      signatureHash: resolution.signatureHash,
      stats: resolution.stats,
      reasonKey: resolution.reasonKey,
    );
    await CollectionMemoryStore.instance.saveCollectorType(
      identity,
      revealRecord: CollectorTypeRevealRecord(
        archetypeId: identity.archetypeId,
        revealedAt: identity.revealedAt,
        signatureHash: identity.signatureHash,
        reasonKey: identity.reasonKey,
        score: resolution.score,
        confidence: resolution.confidence,
        resolverVersion: '4.0',
      ),
    );

    final container = ProviderContainer(overrides: _overridesFor(snap));
    addTearDown(container.dispose);

    expect(container.read(collectorTypeNeedsRevealProvider), isTrue);
    // Hero still shows last revealed ??not live candidate overwrite.
    expect(
      container.read(collectorTypeIdentityProvider)?.archetypeId,
      identity.archetypeId,
    );

    await container
        .read(collectorTypeViewModelProvider.notifier)
        .requestReveal();

    // Version stamped to current; signature unchanged ??loop must end.
    expect(container.read(collectorTypeNeedsRevealProvider), isFalse);
    expect(
      CollectionMemoryStore.instance.cached.revealedResolverVersion,
      kCollectorTypeResolverVersion,
    );
  });

  test('false after successful reveal persists matching candidate', () async {
    final snap = CollectionSnapshot(
      shelfSeries: [testShelfSeries()],
      figureStates: const {},
    );
    await CollectionMemoryStore.instance.saveCollectorType(
      CollectorTypeIdentity(
        archetypeId: CollectorTypeArchetypeId.wanderer,
        revealedAt: DateTime(2026, 1, 1),
        signatureHash: 'stale-signature',
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
          brandBreakdown: {},
          topSeries: [],
          customSeriesRatio: 0,
        ),
        reasonKey: CollectorTypeReasonKey.stillUnfolding,
      ),
    );

    final container = ProviderContainer(overrides: _overridesFor(snap));
    addTearDown(container.dispose);

    expect(container.read(collectorTypeNeedsRevealProvider), isTrue);

    await container
        .read(collectorTypeViewModelProvider.notifier)
        .requestReveal();

    expect(container.read(collectorTypeNeedsRevealProvider), isFalse);
  });

  test(
    'true when a new brand series is added without ownership changes',
    () async {
      final popMart = testShelfSeries(
        id: 's_pop',
        catalogTemplateId: 'catalog_pop',
        taxonomyBrandId: 'pop_mart',
      );
      final revealedSnap = CollectionSnapshot(
        shelfSeries: [popMart],
        figureStates: const {},
      );
      await _saveRevealMatchingLive(revealedSnap);

      final nommi = testShelfSeries(
        id: 's_nommi',
        name: 'NOMMI Series',
        catalogTemplateId: 'catalog_nommi',
        taxonomyBrandId: 'toptoy',
        brand: 'TOPTOY',
        taxonomyIpId: 'nommi',
        ipName: 'NOMMI',
        figures: const [
          ShelfFigure(
            id: 'fig_nommi_0',
            seriesId: 's_nommi',
            name: 'Nommi Fig',
            rarity: 'Regular',
            isSecret: false,
          ),
        ],
      );
      final liveSnap = CollectionSnapshot(
        shelfSeries: [popMart, nommi],
        figureStates: const {},
      );

      final container = ProviderContainer(overrides: _overridesFor(liveSnap));
      addTearDown(container.dispose);

      expect(container.read(collectorTypeNeedsRevealProvider), isTrue);
    },
  );
}
