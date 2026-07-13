import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/collection/insights/application/collector_journey_summary.dart';
import 'package:blindbox_app/features/collection/insights/application/collector_type_explainability.dart';
import 'package:blindbox_app/features/collection/insights/domain/collector_type_archetype.dart';
import 'package:blindbox_app/features/collection/insights/domain/collector_type_identity.dart';
import 'package:blindbox_app/features/collection/insights/domain/collector_type_stats.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/collection_fixtures.dart';

CollectorTypeIdentity _identity(CollectorTypeArchetypeId id) {
  return CollectorTypeIdentity(
    archetypeId: id,
    revealedAt: DateTime(2026, 5, 29),
    signatureHash: 'sig',
    stats: const CollectorTypeStats(
      totalOwned: 0,
      totalWishlist: 0,
      trackedSeries: 3,
      completedSeriesCount: 0,
      masterCompleteSeriesCount: 0,
      completionPercent: 0,
      secretOwned: 0,
      secretSlots: 0,
      brandBreakdown: {'Dreams Inc.': 3},
      topSeries: [],
      customSeriesRatio: 0,
    ),
  );
}

CollectionSnapshot _smiskiSnapshot() {
  return CollectionSnapshot(
    shelfSeries: [
      testShelfSeries(
        id: 's1',
        brand: 'Dreams Inc.',
        taxonomyBrandId: 'dreams_inc',
        ipName: 'Smiski',
        taxonomyIpId: 'smiski',
      ),
      testShelfSeries(
        id: 's2',
        brand: 'Dreams Inc.',
        taxonomyBrandId: 'dreams_inc',
        ipName: 'Smiski',
        taxonomyIpId: 'smiski',
      ),
      testShelfSeries(
        id: 's3',
        brand: 'Dreams Inc.',
        taxonomyBrandId: 'dreams_inc',
        ipName: 'Smiski',
        taxonomyIpId: 'smiski',
      ),
    ],
    figureStates: const {},
  );
}

void main() {
  test('helper line does not appear for typical loyalist history', () {
    final line = resolveCollectorTypeHelperLine(
      identity: _identity(CollectorTypeArchetypeId.loyalist),
      journey: const CollectorJourneySummary(
        ipUniversesExplored: 4,
        seriesExploredOverTime: 7,
        topIps: [],
        journeyAgeLabel: '4 months ago',
      ),
      snapshot: _smiskiSnapshot(),
    );

    expect(line, isNull);
  });

  test(
    'helper line appears for loyalist with broad historical exploration',
    () {
      final line = resolveCollectorTypeHelperLine(
        identity: _identity(CollectorTypeArchetypeId.loyalist),
        journey: const CollectorJourneySummary(
          ipUniversesExplored: 16,
          seriesExploredOverTime: 32,
          topIps: [],
          journeyAgeLabel: '8 months ago',
        ),
        snapshot: _smiskiSnapshot(),
      );

      expect(line, isNotNull);
      expect(
        line,
        contains('collecting journey has explored many different worlds'),
      );
    },
  );

  test('existing collector type behavior unchanged for non-loyalist', () {
    final line = resolveCollectorTypeHelperLine(
      identity: _identity(CollectorTypeArchetypeId.curator),
      journey: const CollectorJourneySummary(
        ipUniversesExplored: 16,
        seriesExploredOverTime: 32,
        topIps: [],
        journeyAgeLabel: '8 months ago',
      ),
      snapshot: _smiskiSnapshot(),
    );

    expect(line, isNull);
  });
}
