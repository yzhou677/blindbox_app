import 'package:blindbox_app/features/collection/insights/domain/collector_type_archetype.dart';
import 'package:blindbox_app/features/collection/insights/domain/collector_type_identity.dart';
import 'package:blindbox_app/features/collection/insights/domain/collector_type_stats.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('identity round-trips through json', () {
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
    );
    final restored = CollectorTypeIdentity.fromJson(identity.toJson());
    expect(restored.archetypeId, CollectorTypeArchetypeId.hunter);
    expect(restored.signatureHash, 'abc123');
    expect(restored.stats.totalOwned, 5);
    expect(restored.stats.brandBreakdown['pop_mart'], 2);
  });
}
