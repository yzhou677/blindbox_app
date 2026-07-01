import 'package:blindbox_app/features/collection/application/collection_insights_dashboard_providers.dart';
import 'package:blindbox_app/features/collection/application/collection_notifier.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/collection/widgets/collection_summary_section.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/collection_fixtures.dart';

void main() {
  test('collectionAggregateStatsProvider recomputes only when snapshot changes', () {
    var buildCount = 0;
    final snap = CollectionSnapshot(
      shelfSeries: [testShelfSeries()],
      figureStates: const {},
    );

    final container = ProviderContainer(
      overrides: [
        collectionNotifierProvider.overrideWith(
          () => _FixedCollectionNotifier(snap),
        ),
        collectionAggregateStatsProvider.overrideWith((ref) {
          ref.watch(collectionNotifierProvider);
          buildCount++;
          return CollectionAggregateStats.fromSnapshot(snap);
        }),
      ],
    );
    addTearDown(container.dispose);

    container.read(collectionAggregateStatsProvider);
    container.read(collectionAggregateStatsProvider);
    expect(buildCount, 1);
  });
}

class _FixedCollectionNotifier extends CollectionNotifier {
  _FixedCollectionNotifier(this._fixed);
  final CollectionSnapshot _fixed;

  @override
  CollectionSnapshot build() => _fixed;
}
