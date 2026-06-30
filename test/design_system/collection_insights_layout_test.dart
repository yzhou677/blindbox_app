import 'package:blindbox_app/core/layout/feed_rhythm.dart';
import 'package:blindbox_app/core/theme/app_spacing.dart';
import 'package:blindbox_app/core/theme/app_theme.dart';
import 'package:blindbox_app/features/catalog/application/catalog_bundle_provider.dart';
import 'package:blindbox_app/features/catalog/catalog_bundle.dart';
import 'package:blindbox_app/features/collection/application/collection_notifier.dart';
import 'package:blindbox_app/features/collection/data/collection_memory_store.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/collection/insights/presentation/collection_insights_screen.dart';
import 'package:blindbox_app/shared/widgets/collectible_section_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/collection_fixtures.dart';

// ---------------------------------------------------------------------------
// Test notifier ??minimal shelf so providers resolve immediately.
// ---------------------------------------------------------------------------

final class _InsightsLayoutTestNotifier extends CollectionNotifier {
  @override
  CollectionSnapshot build() => CollectionSnapshot(
        shelfSeries: [testShelfSeries()],
        figureStates: const {},
      );
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Future<void> _pumpInsights(WidgetTester tester) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        collectionNotifierProvider.overrideWith(_InsightsLayoutTestNotifier.new),
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
        home: const CollectionInsightsScreen(),
      ),
    ),
  );
  await tester.pump();
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    CollectionMemoryStore.instance.resetForTest();
  });

  group('CollectionInsightsScreen ??AppBar layout', () {
    testWidgets('uses FeedRhythm.mainTabAppBarToolbarHeight (52)', (tester) async {
      await _pumpInsights(tester);

      final sliverAppBar = tester.widget<SliverAppBar>(find.byType(SliverAppBar));
      expect(
        sliverAppBar.toolbarHeight,
        FeedRhythm.mainTabAppBarToolbarHeight,
        reason: 'Insights AppBar should match main-tab toolbar height (52)',
      );
    });

    testWidgets('title spacing equals AppSpacing.pageHorizontal', (tester) async {
      await _pumpInsights(tester);

      final sliverAppBar = tester.widget<SliverAppBar>(find.byType(SliverAppBar));
      expect(
        sliverAppBar.titleSpacing,
        AppSpacing.pageHorizontal,
        reason: 'titleSpacing should equal the canonical page horizontal gutter (20)',
      );
    });

    testWidgets('has a back button (leading) ??is a sub-route', (tester) async {
      await _pumpInsights(tester);

      // The leading icon is an arrow_back_rounded; confirm there is a leading
      // widget in the SliverAppBar so the screen reads as a sub-route.
      final sliverAppBar = tester.widget<SliverAppBar>(find.byType(SliverAppBar));
      expect(sliverAppBar.leading, isNotNull);
    });
  });

  group('CollectionInsightsScreen ??section header', () {
    testWidgets('CollectibleSectionHeader is present in scroll view', (tester) async {
      await _pumpInsights(tester);

      expect(find.byType(CollectibleSectionHeader), findsOneWidget);
    });

    testWidgets('below-AppBar gap equals AppSpacing.belowTabAppBar', (tester) async {
      await _pumpInsights(tester);

      // Find all SizedBoxes that are SliverToBoxAdapter children.
      // The first one after the SliverAppBar should be belowTabAppBar (10).
      final sliverToBoxAdapters = tester.widgetList<SliverToBoxAdapter>(
        find.byType(SliverToBoxAdapter),
      );
      final gapBoxes = sliverToBoxAdapters
          .where((s) {
            final child = s.child;
            return child is SizedBox && child.height == AppSpacing.belowTabAppBar;
          })
          .toList();

      expect(
        gapBoxes,
        isNotEmpty,
        reason: 'A SizedBox with height=AppSpacing.belowTabAppBar should follow the SliverAppBar',
      );
    });
  });

  group('CollectionInsightsScreen ??body horizontal gutter', () {
    testWidgets('SliverPadding uses AppSpacing.pageHorizontal on left and right',
        (tester) async {
      await _pumpInsights(tester);

      final sliverPaddings = tester.widgetList<SliverPadding>(
        find.byType(SliverPadding),
      );
      final contentPadding = sliverPaddings
          .where((p) => p.padding.resolve(TextDirection.ltr).left ==
              AppSpacing.pageHorizontal)
          .toList();

      expect(
        contentPadding,
        isNotEmpty,
        reason: 'Body SliverPadding should use AppSpacing.pageHorizontal (20) horizontally',
      );
    });
  });
}
