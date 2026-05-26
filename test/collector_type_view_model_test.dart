import 'package:blindbox_app/features/collection/application/collection_notifier.dart';
import 'package:blindbox_app/features/collection/data/collection_memory_store.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/collection/insights/application/collector_type_providers.dart';
import 'package:blindbox_app/features/collection/insights/application/collector_type_resolver.dart';
import 'package:blindbox_app/features/collection/insights/application/collector_type_view_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/collection_fixtures.dart';

final class TestCollectionNotifier extends CollectionNotifier {
  TestCollectionNotifier(this._snap);
  final CollectionSnapshot _snap;

  @override
  CollectionSnapshot build() => _snap;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    CollectionMemoryStore.instance.resetForTest();
  });

  test('requestReveal holds analyzing for at least minimum duration', () async {
    final snap = CollectionSnapshot(
      shelfSeries: [testShelfSeries()],
      figureStates: const {},
    );
    final container = ProviderContainer(
      overrides: [
        collectionNotifierProvider.overrideWith(
          () => TestCollectionNotifier(snap),
        ),
      ],
    );
    addTearDown(container.dispose);

    final notifier = container.read(collectorTypeViewModelProvider.notifier);
    final future = notifier.requestReveal();
    expect(
      container.read(collectorTypeViewModelProvider),
      isA<CollectorTypeRevealAnalyzing>(),
    );

    final started = DateTime.now();
    await future;
    final elapsed = DateTime.now().difference(started);
    expect(elapsed.inMilliseconds, greaterThanOrEqualTo(collectorTypeAnalyzingHoldMs - 50));

    final stage = container.read(collectorTypeViewModelProvider);
    expect(stage, isA<CollectorTypeRevealRevealed>());
  });
}
