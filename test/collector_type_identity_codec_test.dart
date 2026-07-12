import 'package:blindbox_app/features/collection/insights/domain/collector_type_archetype.dart';
import 'package:blindbox_app/features/collection/insights/domain/collector_type_identity.dart';
import 'package:blindbox_app/features/collection/insights/domain/collector_type_reason_key.dart';
import 'package:blindbox_app/features/collection/insights/domain/collector_type_stats.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('identity round-trips through json including reasonKey', () {
    const stats = CollectorTypeStats(
      totalOwned: 5,
      totalWishlist: 2,
      trackedSeries: 2,
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
    expect(restored.stats.brandBreakdown['pop_mart'], 2);
    expect(restored.reasonKey, CollectorTypeReasonKey.manySecrets);
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
}
