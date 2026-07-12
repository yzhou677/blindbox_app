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
    final series = ShelfSeries(
      id: 'custom_1',
      name: 'My Custom',
      brand: 'Independent',
      ipName: 'Custom IP',
      figures: const [
        ShelfFigure(
          id: 'f1',
          seriesId: 'custom_1',
          name: 'Figure',
          rarity: 'Regular',
          isSecret: false,
        ),
      ],
      shelfAccent: const Color(0xFFE4F2EA),
      notes: 'Archive notes for this series',
      customCoverImageUri: '/local/cover.jpg',
    );
    final snap = CollectionSnapshot(
      shelfSeries: [series],
      figureStates: const {
        'f1': TrackedFigure(
          figureId: 'f1',
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
