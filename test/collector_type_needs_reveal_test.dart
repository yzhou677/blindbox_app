import 'package:blindbox_app/features/collection/application/collection_notifier.dart';
import 'package:blindbox_app/features/collection/data/collection_memory_store.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/collection/insights/application/collector_type_providers.dart';
import 'package:blindbox_app/features/collection/insights/application/collector_type_resolver.dart';
import 'package:blindbox_app/features/collection/insights/domain/collector_type_archetype.dart';
import 'package:blindbox_app/features/collection/insights/domain/collector_type_identity.dart';
import 'package:blindbox_app/features/collection/insights/domain/collector_type_stats.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/collection_fixtures.dart';

final class NeedsRevealTestNotifier extends CollectionNotifier {
  NeedsRevealTestNotifier(this._snap);
  final CollectionSnapshot _snap;

  @override
  CollectionSnapshot build() => _snap;
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
    final container = ProviderContainer(
      overrides: [
        collectionNotifierProvider.overrideWith(
          () => NeedsRevealTestNotifier(snap),
        ),
      ],
    );
    addTearDown(container.dispose);

    expect(container.read(collectorTypeNeedsRevealProvider), isFalse);
  });

  test('false when stored signature matches live shelf', () async {
    final snap = CollectionSnapshot(
      shelfSeries: [testShelfSeries()],
      figureStates: const {},
    );
    final signature = computeCollectorTypeSignatureHash(snap);
    await CollectionMemoryStore.instance.saveCollectorType(
      CollectorTypeIdentity(
        archetypeId: CollectorTypeArchetypeId.wanderer,
        revealedAt: DateTime(2026, 1, 1),
        signatureHash: signature,
        stats: const CollectorTypeStats(
          totalOwned: 0,
          totalWishlist: 0,
          trackedSeries: 1,
          completionPercent: 0,
          secretOwned: 0,
          secretSlots: 0,
          brandBreakdown: {},
          topSeries: [],
          customSeriesRatio: 0,
        ),
      ),
    );

    final container = ProviderContainer(
      overrides: [
        collectionNotifierProvider.overrideWith(
          () => NeedsRevealTestNotifier(snap),
        ),
      ],
    );
    addTearDown(container.dispose);

    expect(container.read(collectorTypeNeedsRevealProvider), isFalse);
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
          completionPercent: 0,
          secretOwned: 0,
          secretSlots: 0,
          brandBreakdown: {},
          topSeries: [],
          customSeriesRatio: 0,
        ),
      ),
    );

    final container = ProviderContainer(
      overrides: [
        collectionNotifierProvider.overrideWith(
          () => NeedsRevealTestNotifier(snap),
        ),
      ],
    );
    addTearDown(container.dispose);

    expect(container.read(collectorTypeNeedsRevealProvider), isTrue);
  });
}
