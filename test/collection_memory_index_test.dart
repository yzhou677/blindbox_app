import 'package:blindbox_app/features/collection/application/collection_memory_index.dart';
import 'package:blindbox_app/features/collection/data/collection_memory_store.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/collection/domain/collection_memory_moment.dart';
import 'package:flutter_test/flutter_test.dart';
import 'helpers/collection_fixtures.dart';

void main() {
  setUp(() {
    CollectionMemoryStore.instance.resetForTest();
  });

  test('pickPrimaryMemoryMoment prefers recent completion', () {
    final snap = CollectionSnapshot(
      shelfSeries: [testShelfSeries(id: 's1')],
      figureStates: const {},
    );
    final moments = [
      const CollectionMemoryMoment(
        kind: CollectionMemoryMomentKind.shelfGrowing,
      ),
      CollectionMemoryMoment(
        kind: CollectionMemoryMomentKind.recentlyCompletedLineup,
        seriesName: 'Macaron',
      ),
    ];
    final picked = pickPrimaryMemoryMoment(snap, moments);
    expect(picked?.kind, CollectionMemoryMomentKind.recentlyCompletedLineup);
  });

  test('long loved universe from ip depth', () async {
    final store = CollectionMemoryStore.instance;
    store.resetForTest();
    final a = testShelfSeries(id: 's1', taxonomyIpId: 'ip_love');
    final b = testShelfSeries(id: 's2', taxonomyIpId: 'ip_love');
    final c = testShelfSeries(id: 's3', taxonomyIpId: 'ip_other');

    final empty = CollectionSnapshot(shelfSeries: const [], figureStates: {});
    var prev = empty;
    for (final s in [a, b, c]) {
      final next = CollectionSnapshot(
        shelfSeries: [...prev.shelfSeries, s],
        figureStates: const {},
      );
      await store.recordTransitions(previous: prev, next: next);
      prev = next;
    }

    final moments = buildCollectionMemoryMoments(prev);
    expect(
      moments.any((m) => m.kind == CollectionMemoryMomentKind.longLovedUniverse),
      isTrue,
    );
  });
}
