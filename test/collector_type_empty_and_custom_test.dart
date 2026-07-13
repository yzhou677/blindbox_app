import 'package:blindbox_app/features/collection/application/shelf_emotional_interpreter.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/collection/insights/application/collector_type_resolver.dart';
import 'package:blindbox_app/features/collection/insights/domain/collector_type_archetype.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('empty shelf resolves to wanderer', () {
    final snap = CollectionSnapshot.emptyTest();
    final identity = resolveCollectorType(
      snapshot: snap,
      profile: interpretShelf(snap),
      revealedAt: DateTime(2026, 1, 1),
    );
    expect(identity.archetypeId, CollectorTypeArchetypeId.wanderer);
  });

  test('custom-only shelf with notes resolves to worldbuilder', () {
    final series = [
      for (var i = 0; i < 2; i++)
        ShelfSeries(
          id: 'custom_$i',
          name: 'My Custom $i',
          brand: 'Independent',
          ipName: 'Custom IP $i',
          figures: [
            ShelfFigure(
              id: 'f$i',
              seriesId: 'custom_$i',
              name: 'Figure',
              rarity: 'Regular',
              isSecret: false,
            ),
          ],
          shelfAccent: const Color(0xFFE4F2EA),
          notes: i == 0 ? 'Archive notes for this series' : null,
          customCoverImageUri: i == 0 ? '/local/cover.jpg' : null,
        ),
    ];
    final snap = CollectionSnapshot(
      shelfSeries: series,
      figureStates: {
        for (final s in series)
          s.figures.first.id: TrackedFigure(
            figureId: s.figures.first.id,
            state: FigureCollectionState.owned,
          ),
      },
    );
    final identity = resolveCollectorType(
      snapshot: snap,
      profile: interpretShelf(snap),
      revealedAt: DateTime(2026, 1, 1),
    );
    expect(identity.stats.customSeriesRatio, greaterThan(0.5));
    expect(identity.archetypeId, CollectorTypeArchetypeId.worldbuilder);
  });
}
