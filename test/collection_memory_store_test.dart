import 'package:blindbox_app/features/collection/data/collection_memory_store.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'helpers/collection_fixtures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    CollectionMemoryStore.instance.resetForTest();
  });

  test('records first secret owned once', () async {
    final store = CollectionMemoryStore.instance;
    final series = testShelfSeries(
      figures: [
        const ShelfFigure(
          id: 'sec',
          seriesId: 'series_test',
          name: 'Secret',
          rarity: 'Secret',
          isSecret: true,
        ),
      ],
    );

    final before = CollectionSnapshot(shelfSeries: [series], figureStates: {});
    final after = CollectionSnapshot(
      shelfSeries: [series],
      figureStates: {
        'sec': const TrackedFigure(
          figureId: 'sec',
          state: FigureCollectionState.owned,
        ),
      },
    );

    await store.recordTransitions(previous: before, next: after);
    expect(store.cached.firstSecretOwnedAtMs, isNotNull);

    await store.recordTransitions(previous: after, next: after);
    final firstMs = store.cached.firstSecretOwnedAtMs;
    expect(firstMs, isNotNull);
  });
}
