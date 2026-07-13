import 'package:blindbox_app/features/collection/data/collection_memory_store.dart';
import 'package:blindbox_app/features/collection/insights/domain/collector_type_archetype.dart';
import 'package:blindbox_app/features/collection/insights/domain/collector_type_identity.dart';
import 'package:blindbox_app/features/collection/insights/domain/collector_type_reason_key.dart';
import 'package:blindbox_app/features/collection/insights/domain/collector_type_reveal_record.dart';
import 'package:blindbox_app/features/collection/insights/domain/collector_type_stats.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    CollectionMemoryStore.instance.resetForTest();
  });

  test('saveCollectorType persists identity, reason, and reveal record', () async {
    final store = CollectionMemoryStore.instance;
    const stats = CollectorTypeStats(
      totalOwned: 3,
      totalWishlist: 1,
      trackedSeries: 1,
      completedSeriesCount: 0,
      masterCompleteSeriesCount: 0,
      masterEligibleSeriesCount: 0,
      completionPercent: 50,
      secretOwned: 0,
      secretSlots: 0,
      brandBreakdown: {},
      topSeries: [],
      customSeriesRatio: 0,
    );
    final identity = CollectorTypeIdentity(
      archetypeId: CollectorTypeArchetypeId.curator,
      revealedAt: DateTime(2026, 5, 1),
      signatureHash: 'hash',
      stats: stats,
      reasonKey: CollectorTypeReasonKey.intentionalSpread,
    );

    await store.saveCollectorType(identity);
    expect(
      store.cached.collectorTypeIdentity?.archetypeId,
      CollectorTypeArchetypeId.curator,
    );
    expect(
      store.cached.collectorTypeIdentity?.reasonKey,
      CollectorTypeReasonKey.intentionalSpread,
    );
    expect(store.cached.collectorTypeRevealHistory, hasLength(1));
    expect(
      store.cached.collectorTypeRevealHistory.single.archetypeId,
      CollectorTypeArchetypeId.curator,
    );
    expect(
      store.cached.collectorTypeRevealHistory.single.reasonKey,
      CollectorTypeReasonKey.intentionalSpread,
    );
    expect(store.cached.collectorTypeRevealHistory.single.score, 0);
    expect(store.cached.collectorTypeRevealHistory.single.confidence, 0);
    expect(store.cached.collectorTypeResolverVersion, kCollectorTypeResolverVersion);
    expect(store.cached.revealedResolverVersion, kCollectorTypeResolverVersion);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.containsKey('collection_memory_v3'), isTrue);
    final raw = prefs.getString('collection_memory_v3');
    expect(raw, contains('curator'));
    expect(raw, contains('hash'));
    expect(raw, contains('intentionalSpread'));
    expect(raw, contains('collectorTypeResolverVersion'));
  });

  test('clearCollectorType removes identity fields', () async {
    final store = CollectionMemoryStore.instance;
    await store.saveCollectorType(
      CollectorTypeIdentity(
        archetypeId: CollectorTypeArchetypeId.wanderer,
        revealedAt: DateTime(2026, 1, 1),
        signatureHash: 'x',
        stats: const CollectorTypeStats(
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
        ),
      ),
    );
    await store.clearCollectorType();
    expect(store.cached.collectorTypeIdentity, isNull);
    expect(store.cached.collectorTypeRevealHistory, isEmpty);
  });
}
