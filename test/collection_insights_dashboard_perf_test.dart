import 'package:blindbox_app/core/theme/collectible_tokens.dart';
import 'package:blindbox_app/features/collection/application/collection_insights_dashboard_providers.dart';
import 'package:blindbox_app/features/collection/application/collection_notifier.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/collection/widgets/collection_insights_dashboard_host.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/collection_fixtures.dart';

void main() {
  testWidgets('dashboard toggle does not rebuild shelf feed sibling', (
    tester,
  ) async {
    final shelfBuilds = _BuildCounter();

    final snap = CollectionSnapshot(
      shelfSeries: [testShelfSeries()],
      figureStates: const {},
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          collectionNotifierProvider.overrideWith(
            () => _FixedCollectionNotifier(snap),
          ),
          collectionInsightsDashboardInputsProvider.overrideWith((ref) {
            final stats = ref.watch(collectionAggregateStatsProvider);
            return CollectionInsightsDashboardInputs(stats: stats);
          }),
        ],
        child: MaterialApp(
          theme: ThemeData(
            extensions: [CollectibleTokens.forBrightness(Brightness.light)],
          ),
          home: Scaffold(
            body: Column(
              children: [
                const CollectionInsightsDashboardHost(),
                Expanded(
                  child: _AuditWrapper(
                    counter: shelfBuilds,
                    child: const Text('shelf-feed-stub'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final buildsBeforeToggle = shelfBuilds.count;
    shelfBuilds.reset();

    await tester.tap(find.byKey(const Key('collection_insights_dashboard_toggle')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 240));
    await tester.pumpAndSettle();

    expect(
      shelfBuilds.count,
      0,
      reason: 'shelf sibling should not rebuild when dashboard toggles',
    );
    expect(buildsBeforeToggle, greaterThan(0));
  });
}

final class _BuildCounter {
  int count = 0;
  void reset() => count = 0;
}

class _AuditWrapper extends StatelessWidget {
  const _AuditWrapper({required this.counter, required this.child});

  final _BuildCounter counter;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    counter.count++;
    return child;
  }
}

class _FixedCollectionNotifier extends CollectionNotifier {
  _FixedCollectionNotifier(this._fixed);
  final CollectionSnapshot _fixed;

  @override
  CollectionSnapshot build() => _fixed;
}
