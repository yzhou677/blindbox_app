import 'package:blindbox_app/core/theme/app_theme.dart';
import 'package:blindbox_app/features/catalog/application/catalog_bundle_provider.dart';
import 'package:blindbox_app/features/catalog/catalog_bundle.dart';
import 'package:blindbox_app/features/collection/application/collection_notifier.dart';
import 'package:blindbox_app/features/collection/application/collection_shelf_ui_prefs_provider.dart';
import 'package:blindbox_app/features/collection/collection_screen.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/collection/widgets/collection_insights_dashboard_host.dart';
import 'package:blindbox_app/shared/widgets/app_search_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/collection_fixtures.dart';

final class _FixedCollectionNotifier extends CollectionNotifier {
  _FixedCollectionNotifier(this._fixed);
  final CollectionSnapshot _fixed;

  @override
  CollectionSnapshot build() => _fixed;
}

Finder get _searchField => find.descendant(
      of: find.byType(AppSearchField),
      matching: find.byType(TextField),
    );

Future<void> _pumpCollectionScreen(
  WidgetTester tester, {
  required CollectionSnapshot snap,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        collectionNotifierProvider.overrideWith(
          () => _FixedCollectionNotifier(snap),
        ),
        collectionShelfUiPrefsProvider.overrideWith(
          CollectionShelfUiPrefsNotifier.new,
        ),
        catalogBundleProvider.overrideWith(
          (ref) async => const CatalogSeedBundle(
            brands: [],
            ips: [],
            series: [],
            figures: [],
          ),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: const CollectionScreen(),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 200));
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    CollectionInsightsDashboardHost.debugBuildCount = 0;
  });

  testWidgets('search keystroke does not rebuild dashboard before debounce', (
    tester,
  ) async {
    final snap = CollectionSnapshot(
      shelfSeries: [
        testShelfSeries(id: 'a', name: 'Alpha Series'),
        testShelfSeries(id: 'b', name: 'Bravo Series'),
      ],
      figureStates: const {},
    );

    await _pumpCollectionScreen(tester, snap: snap);

    CollectionInsightsDashboardHost.debugBuildCount = 0;

    await tester.enterText(_searchField, 'a');
    await tester.pump();

    expect(
      CollectionInsightsDashboardHost.debugBuildCount,
      0,
      reason: 'typing should not rebuild browse subtree before debounce',
    );

    await tester.pump(const Duration(milliseconds: 125));
    await tester.pump();

    expect(
      CollectionInsightsDashboardHost.debugBuildCount,
      1,
      reason: 'debounced query should rebuild dashboard exactly once',
    );
  });

  testWidgets(
    'rapid multi-character typing keeps dashboard idle until debounce settles',
    (tester) async {
      final snap = CollectionSnapshot(
        shelfSeries: [
          testShelfSeries(id: 'a', name: 'Alpha Series'),
          testShelfSeries(id: 'b', name: 'Bravo Series'),
        ],
        figureStates: const {},
      );

      await _pumpCollectionScreen(tester, snap: snap);
      CollectionInsightsDashboardHost.debugBuildCount = 0;

      // Simulate fast typing: each step resets the 125ms debounce timer.
      const typingSteps = ['h', 'hi', 'hi', 'hi l', 'hi lu'];
      for (final step in typingSteps) {
        await tester.enterText(_searchField, step);
        await tester.pump();
        expect(
          CollectionInsightsDashboardHost.debugBuildCount,
          0,
          reason: 'dashboard must stay idle while typing "$step"',
        );
      }

      // Debounce window not elapsed yet — still no dashboard rebuild.
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        CollectionInsightsDashboardHost.debugBuildCount,
        0,
        reason: 'dashboard must not rebuild before debounce completes',
      );

      await tester.pump(const Duration(milliseconds: 25));
      await tester.pump();

      expect(
        CollectionInsightsDashboardHost.debugBuildCount,
        1,
        reason: 'debounced query should rebuild dashboard exactly once',
      );
    },
  );
}
