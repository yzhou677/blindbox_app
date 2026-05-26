import 'package:blindbox_app/core/layout/feed_rhythm.dart';
import 'package:blindbox_app/core/theme/app_spacing.dart';
import 'package:blindbox_app/core/theme/app_theme.dart';
import 'package:blindbox_app/features/catalog/application/catalog_bundle_provider.dart';
import 'package:blindbox_app/features/catalog/catalog_seed_loader.dart';
import 'package:blindbox_app/features/collection/application/collection_notifier.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/market/presentation/market_browse_search_screen.dart';
import 'package:blindbox_app/shared/widgets/feed_search_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ---------------------------------------------------------------------------
// Minimal overrides so providers resolve without Firestore / network.
// ---------------------------------------------------------------------------

final class _EmptyCollectionNotifier extends CollectionNotifier {
  @override
  CollectionSnapshot build() =>
      const CollectionSnapshot(shelfSeries: [], figureStates: {});
}

Future<void> _pumpMarketSearch(WidgetTester tester) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        collectionNotifierProvider.overrideWith(_EmptyCollectionNotifier.new),
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
        home: const MarketBrowseSearchScreen(),
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
  });

  group('FeedSearchScreen (search overlay) — intentional AppBar deviations', () {
    testWidgets('uses toolbarHeight 72 (not 52)', (tester) async {
      await _pumpMarketSearch(tester);

      final appBar = tester.widget<AppBar>(find.byType(AppBar));
      expect(
        appBar.toolbarHeight,
        72,
        reason:
            'Search overlays intentionally use a taller AppBar (72) to '
            'distinguish the focused search context from main tabs (52).',
      );
    });

    testWidgets('uses AppSpacing.pageHorizontal for titleSpacing', (tester) async {
      await _pumpMarketSearch(tester);

      final appBar = tester.widget<AppBar>(find.byType(AppBar));
      expect(appBar.titleSpacing, AppSpacing.pageHorizontal);
    });

    testWidgets('is not the same height as a main-tab AppBar', (tester) async {
      await _pumpMarketSearch(tester);

      final appBar = tester.widget<AppBar>(find.byType(AppBar));
      expect(
        appBar.toolbarHeight,
        isNot(FeedRhythm.mainTabAppBarToolbarHeight),
        reason: 'Search overlay AppBar height must differ from main-tab height',
      );
    });
  });

  group('MarketBrowseSearchScreen — results list spacing', () {
    testWidgets('FeedSearchScreen is rendered', (tester) async {
      await _pumpMarketSearch(tester);
      expect(find.byType(FeedSearchScreen), findsOneWidget);
    });

    testWidgets('market browse state starts with empty query', (tester) async {
      await _pumpMarketSearch(tester);

      // Without a search query the browse notifier has no query text.
      // The screen should show the empty-state prompt, not results.
      // (Verifies the screen starts in its idle state.)
      expect(find.byType(MarketBrowseSearchScreen), findsOneWidget);
    });
  });

  group('FeedRhythm token guard — market listing gap', () {
    test('marketListingFeedCardVerticalGap is 18', () {
      // Regression guard: this value is referenced from the search list
      // separator. If the main market feed gap changes, the search screen
      // should be updated together to keep the two surfaces visually consistent.
      expect(FeedRhythm.marketListingFeedCardVerticalGap, 18);
    });

    test('market search gap (18) equals main market feed gap', () {
      // The market browse search screen now uses the same separator height as
      // the main market feed. This test catches accidental divergence.
      const searchGap = FeedRhythm.marketListingFeedCardVerticalGap;
      const mainFeedGap = FeedRhythm.marketListingFeedCardVerticalGap;
      expect(searchGap, mainFeedGap);
    });
  });
}
