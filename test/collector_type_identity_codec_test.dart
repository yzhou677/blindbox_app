import 'package:blindbox_app/features/collection/insights/domain/collector_type_archetype.dart';
import 'package:blindbox_app/features/collection/insights/domain/collector_type_identity.dart';
import 'package:blindbox_app/features/collection/insights/domain/collector_type_reason_key.dart';
import 'package:blindbox_app/features/collection/insights/domain/collector_type_stats.dart';
import 'package:blindbox_app/features/collection/insights/presentation/collector_type_copy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('identity round-trips through json including reasonKey', () {
    const stats = CollectorTypeStats(
      totalOwned: 5,
      totalWishlist: 2,
      trackedSeries: 2,
      completedSeriesCount: 0,
      masterCompleteSeriesCount: 0,
      masterEligibleSeriesCount: 0,
      completionPercent: 80,
      secretOwned: 1,
      secretSlots: 3,
      brandBreakdown: {'pop_mart': 2},
      topSeries: ['Series A'],
      customSeriesRatio: 0,
    );
    final identity = CollectorTypeIdentity(
      archetypeId: CollectorTypeArchetypeId.hunter,
      revealedAt: DateTime(2026, 5, 1, 12),
      signatureHash: 'abc123',
      stats: stats,
      reasonKey: CollectorTypeReasonKey.manySecrets,
    );
    final restored = CollectorTypeIdentity.fromJson(identity.toJson());
    expect(restored.archetypeId, CollectorTypeArchetypeId.hunter);
    expect(restored.signatureHash, 'abc123');
    expect(restored.stats.totalOwned, 5);
    expect(restored.stats.completedSeriesCount, 0);
    expect(restored.stats.brandBreakdown['pop_mart'], 2);
    expect(restored.reasonKey, CollectorTypeReasonKey.manySecrets);

    const statsWithTiers = CollectorTypeStats(
      totalOwned: 10,
      totalWishlist: 0,
      trackedSeries: 3,
      completedSeriesCount: 2,
      masterCompleteSeriesCount: 1,
      masterEligibleSeriesCount: 1,
      completionPercent: 90,
      secretOwned: 4,
      secretSlots: 6,
      brandBreakdown: {},
      topSeries: [],
      customSeriesRatio: 0,
    );
    final withTiers = CollectorTypeIdentity(
      archetypeId: CollectorTypeArchetypeId.completionist,
      revealedAt: DateTime(2026, 6, 1),
      signatureHash: 'tier',
      stats: statsWithTiers,
    );
    final restoredTiers = CollectorTypeIdentity.fromJson(withTiers.toJson());
    expect(restoredTiers.stats.completedSeriesCount, 2);
    expect(restoredTiers.stats.masterCompleteSeriesCount, 1);
    expect(restoredTiers.stats.masterEligibleSeriesCount, 1);
    expect(restoredTiers.stats.secretOwned, 4);
  });

  test('legacy json without reasonKey heals Loyalist to dominantUniverse', () {
    final restored = CollectorTypeIdentity.fromJson({
      'archetypeId': 'loyalist',
      'revealedAtMs': DateTime(2026, 1, 1).millisecondsSinceEpoch,
      'signatureHash': 'old',
      'stats': {
        'totalOwned': 1,
        'totalWishlist': 0,
        'trackedSeries': 1,
        'completionPercent': 10,
        'secretOwned': 0,
        'secretSlots': 0,
        'brandBreakdown': <String, dynamic>{},
        'topSeries': <dynamic>[],
        'customSeriesRatio': 0,
      },
    });
    expect(restored.reasonKey, CollectorTypeReasonKey.dominantUniverse);
  });

  test('legacy json without reasonKey keeps stillUnfolding for Wanderer', () {
    final restored = CollectorTypeIdentity.fromJson({
      'archetypeId': 'wanderer',
      'revealedAtMs': DateTime(2026, 1, 1).millisecondsSinceEpoch,
      'signatureHash': 'old',
      'stats': {
        'totalOwned': 0,
        'totalWishlist': 0,
        'trackedSeries': 0,
        'completionPercent': 0,
        'secretOwned': 0,
        'secretSlots': 0,
        'brandBreakdown': <String, dynamic>{},
        'topSeries': <dynamic>[],
        'customSeriesRatio': 0,
      },
    });
    expect(restored.reasonKey, CollectorTypeReasonKey.stillUnfolding);
  });

  test('healed() upgrades Loyalist stillUnfolding', () {
    final stale = CollectorTypeIdentity(
      archetypeId: CollectorTypeArchetypeId.loyalist,
      revealedAt: DateTime(2026, 1, 1),
      signatureHash: 'x',
      stats: const CollectorTypeStats(
        totalOwned: 1,
        totalWishlist: 0,
        trackedSeries: 1,
        completedSeriesCount: 0,
        masterCompleteSeriesCount: 0,
        masterEligibleSeriesCount: 0,
        completionPercent: 10,
        secretOwned: 0,
        secretSlots: 0,
        brandBreakdown: {},
        topSeries: [],
        customSeriesRatio: 0,
      ),
      reasonKey: CollectorTypeReasonKey.stillUnfolding,
    );
    expect(stale.displayReasonKey, CollectorTypeReasonKey.dominantUniverse);
    expect(stale.healed().reasonKey, CollectorTypeReasonKey.dominantUniverse);
  });

  test('legacy daydreamCollector loads as dreamer', () {
    final daydream = CollectorTypeIdentity.fromJson({
      'archetypeId': 'daydreamCollector',
      'revealedAtMs': DateTime(2026, 1, 1).millisecondsSinceEpoch,
      'signatureHash': 'old',
      'stats': {
        'totalOwned': 1,
        'totalWishlist': 5,
        'trackedSeries': 1,
        'completionPercent': 10,
        'secretOwned': 0,
        'secretSlots': 0,
        'brandBreakdown': <String, dynamic>{},
        'topSeries': <dynamic>[],
        'customSeriesRatio': 0,
      },
      'reasonKey': 'wishlistDominates',
    });
    expect(daydream.archetypeId, CollectorTypeArchetypeId.dreamer);
    expect(daydream.reasonKey, CollectorTypeReasonKey.highWishlist);
  });

  test(
    'legacy archivist id and livingArchive reason migrate to Worldbuilder',
    () {
      final restored = CollectorTypeIdentity.fromJson({
        'archetypeId': 'archivist',
        'revealedAtMs': DateTime(2026, 1, 1).millisecondsSinceEpoch,
        'signatureHash': 'old',
        'stats': {
          'totalOwned': 1,
          'totalWishlist': 0,
          'trackedSeries': 1,
          'completionPercent': 10,
          'secretOwned': 0,
          'secretSlots': 0,
          'brandBreakdown': <String, dynamic>{},
          'topSeries': <dynamic>[],
          'customSeriesRatio': 0,
        },
        'reasonKey': 'livingArchive',
      });
      expect(restored.archetypeId, CollectorTypeArchetypeId.worldbuilder);
      expect(restored.reasonKey, CollectorTypeReasonKey.inventedWorlds);
      expect(
        CollectorTypeCopy.becauseLineFor(restored),
        'Because custom series are a strong signal in this reveal.',
      );
    },
  );
}
