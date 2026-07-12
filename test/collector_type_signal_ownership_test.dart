import 'package:blindbox_app/features/collection/application/shelf_emotional_interpreter.dart';
import 'package:blindbox_app/features/collection/data/collection_memory_store.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/collection/insights/application/collector_journey_summary.dart';
import 'package:blindbox_app/features/collection/insights/application/collector_type_resolver.dart';
import 'package:blindbox_app/features/collection/insights/domain/collector_type_archetype.dart';
import 'package:blindbox_app/features/collection/insights/domain/collector_type_reveal_record.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Collector Type 2.0 — bounded-context ownership regressions.
///
/// Identity must ignore Journey memory. Journey metrics must stay on Journey.

ShelfSeries _series({
  required String id,
  required String ip,
  required String brand,
  required int figs,
  String? notes,
  bool customLocal = false,
}) {
  // Product: series notes exist only on custom series.
  assert(
    customLocal || notes == null,
    'notes require customLocal: true (catalog series have no notes UI)',
  );
  return ShelfSeries(
    id: id,
    name: 'S$id',
    brand: brand,
    ipName: ip,
    figures: [
      for (var i = 0; i < figs; i++)
        ShelfFigure(
          id: '${id}_$i',
          seriesId: id,
          name: 'F$i',
          rarity: 'R',
          isSecret: false,
        ),
    ],
    shelfAccent: const Color(0xFFE4F2EA),
    taxonomyBrandId: brand,
    taxonomyIpId: ip,
    catalogTemplateId: customLocal ? null : 'catalog_$id',
    notes: customLocal ? notes : null,
  );
}

TrackedFigure _owned(String id) =>
    TrackedFigure(figureId: id, state: FigureCollectionState.owned);

void main() {
  test('resolverVersion is 5.2 after reveal lifecycle contract', () {
    expect(kCollectorTypeResolverVersion, '5.2');
  });

  test('Curator score ignores historical ipSeriesDepth', () {
    // Three brands / IPs equally — gallery without Loyalist dominance.
    final series = [
      _series(id: 'a1', ip: 'ip1', brand: 'POP MART', figs: 3),
      _series(id: 'a2', ip: 'ip2', brand: 'Sonny Angel', figs: 3),
      _series(id: 'a3', ip: 'ip3', brand: 'TOP TOY', figs: 3),
    ];
    final states = <String, TrackedFigure>{
      for (final s in series)
        for (final f in s.figures.take(1)) f.id: _owned(f.id),
    };
    final snap = CollectionSnapshot(shelfSeries: series, figureStates: states);
    final profile = interpretShelf(snap);

    final identity = resolveCollectorType(
      snapshot: snap,
      profile: profile,
      revealedAt: DateTime(2026, 7, 1),
    );

    // brandSpread=3, shelfIpSpread=3 → 25 + 24 + 15 = 64
    expect(identity.scores[CollectorTypeArchetypeId.curator], 64);

    // Journey still records deep exploration — Identity must not change.
    final journey = buildCollectorJourneySummary(
      memory: CollectionMemoryData(
        ipSeriesDepth: {for (var i = 1; i <= 17; i++) 'hist$i': 1},
        firstSeriesAddedAtMs: DateTime(2024, 1, 1).millisecondsSinceEpoch,
      ),
      snapshot: snap,
      now: DateTime(2026, 7, 1),
    );
    expect(journey.ipUniversesExplored, 17);

    final again = resolveCollectorType(
      snapshot: snap,
      profile: profile,
      revealedAt: DateTime(2026, 7, 1),
    );
    expect(
      again.scores[CollectorTypeArchetypeId.curator],
      identity.scores[CollectorTypeArchetypeId.curator],
    );
  });

  test('Worldbuilder ignores firstSeriesAddedAt tenure', () {
    final snap = CollectionSnapshot(
      shelfSeries: [
        ShelfSeries(
          id: 'n1',
          name: 'My World',
          brand: 'Independent',
          ipName: 'Mine',
          figures: const [
            ShelfFigure(
              id: 'n1_0',
              seriesId: 'n1',
              name: 'F0',
              rarity: 'R',
              isSecret: false,
            ),
            ShelfFigure(
              id: 'n1_1',
              seriesId: 'n1',
              name: 'F1',
              rarity: 'R',
              isSecret: false,
            ),
          ],
          shelfAccent: const Color(0xFFE4F2EA),
          notes: 'kept',
        ),
      ],
      figureStates: {'n1_0': _owned('n1_0')},
    );
    final identity = resolveCollectorType(
      snapshot: snap,
      profile: interpretShelf(snap),
      revealedAt: DateTime(2026, 7, 1),
    );
    // ratio=1, series=1, figures=2, notes=1 → 20+55+10+2.5+5
    expect(identity.scores[CollectorTypeArchetypeId.worldbuilder], 92.5);

    final journey = buildCollectorJourneySummary(
      memory: CollectionMemoryData(
        firstSeriesAddedAtMs: DateTime(2020, 1, 1).millisecondsSinceEpoch,
        ipSeriesDepth: const {'ip1': 1},
      ),
      snapshot: snap,
      now: DateTime(2026, 7, 1),
    );
    expect(journey.journeyAgeLabel, isNotNull);
    expect(journey.hasHistory, isTrue);
  });

  test('Completionist wins completed multi-IP shelf that Journey used to tip to Curator',
      () {
    final series = [
      _series(id: 'a1', ip: 'ip1', brand: 'pop', figs: 3),
      _series(id: 'a2', ip: 'ip2', brand: 'pop', figs: 3),
      _series(id: 'a3', ip: 'ip3', brand: 'pop', figs: 3),
    ];
    final states = <String, TrackedFigure>{
      for (final s in series)
        for (final f in s.figures) f.id: _owned(f.id),
    };
    final snap = CollectionSnapshot(shelfSeries: series, figureStates: states);
    final identity = resolveCollectorType(
      snapshot: snap,
      profile: interpretShelf(snap),
      revealedAt: DateTime(2026, 7, 1),
    );

    expect(identity.archetypeId, CollectorTypeArchetypeId.completionist);
    expect(
      identity.scores[CollectorTypeArchetypeId.completionist]! >
          identity.scores[CollectorTypeArchetypeId.curator]!,
      isTrue,
    );

    // Journey depth remains independent and high.
    final journey = buildCollectorJourneySummary(
      memory: CollectionMemoryData(
        ipSeriesDepth: {for (var i = 1; i <= 17; i++) 'hist$i': 1},
        firstSeriesAddedAtMs: DateTime(2024, 1, 1).millisecondsSinceEpoch,
      ),
      snapshot: snap,
      now: DateTime(2026, 7, 1),
    );
    expect(journey.ipUniversesExplored, 17);
  });
}
