import 'package:blindbox_app/features/collection/application/collection_evolution_interpreter.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/collection/domain/collection_evolution.dart';
import 'package:blindbox_app/features/collection/domain/shelf_era.dart';
import 'package:blindbox_app/features/collection/domain/shelf_mood.dart';
import 'package:flutter_test/flutter_test.dart';
import 'helpers/collection_fixtures.dart';

void main() {
  test('detects mood softening between eras', () {
    final snap = CollectionSnapshot(
      shelfSeries: [
        testShelfSeries(id: 's1', taxonomyIpId: 'ip_a'),
        testShelfSeries(id: 's2', taxonomyIpId: 'ip_b'),
      ],
      figureStates: const {},
    );

    final prior = const ShelfEra(
      shelfMood: ShelfMood.playful,
      seriesCount: 2,
      secretOwnedCount: 0,
    );

    final evolution = interpretCollectionEvolution(snap: snap, priorEra: prior);
    expect(evolution, isNotNull);
  });

  test('returns null when prior era missing', () {
    final snap = CollectionSnapshot(
      shelfSeries: [testShelfSeries()],
      figureStates: const {},
    );
    expect(
      interpretCollectionEvolution(snap: snap, priorEra: null),
      isNull,
    );
  });
}
