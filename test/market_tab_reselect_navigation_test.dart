import 'package:blindbox_app/core/router/app_router.dart';
import 'package:blindbox_app/features/collection/data/series_release_lookup.dart';
import 'package:blindbox_app/features/home/application/home_feed_provider.dart';
import 'package:blindbox_app/features/home/data/mock_latest_drops.dart';
import 'package:blindbox_app/features/market/application/market_browse_root_navigation.dart';
import 'package:blindbox_app/features/market/application/market_search_browse_notifier.dart';
import 'package:blindbox_app/features/market/market_detail_screen.dart';
import 'package:blindbox_app/features/market/presentation/market_browse_search_screen.dart';
import 'package:blindbox_app/features/official_feed/application/official_feed_providers.dart';
import 'package:blindbox_app/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

List<Override> _marketNavTestOverrides() => [
  homeFeedSnapshotProvider.overrideWith(
    (_) async => HomeFeedSnapshot(
      latest: mockSeriesReleases,
      trending: mockSeriesReleases.skip(1).take(4).toList(growable: false),
    ),
  ),
  officialFeedListProvider.overrideWith((_) async => const []),
  seriesReleaseLookupProvider.overrideWithValue(mockSeriesReleaseByDropId),
];

Finder _marketNavTab() => find.descendant(
      of: find.byType(NavigationBar),
      matching: find.text('Market'),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    appRouter.go('/collection');
  });

  testWidgets(
    'Market tab reselect from search restores browse root chrome',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: _marketNavTestOverrides(),
          child: const BlindboxApp(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.text('Market'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      expect(appRouter.state.uri.path, kMarketBrowseRootPath);
      expect(find.text('Brand'), findsOneWidget);
      expect(find.text('Collectibles'), findsOneWidget);

      appRouter.push(kMarketSearchRoutePath);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(appRouter.state.uri.path, kMarketSearchRoutePath);
      expect(find.text('Search market'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'labubu');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 450));

      final searchState = ProviderScope.containerOf(
        tester.element(find.byType(MarketBrowseSearchScreen)),
      ).read(marketSearchBrowseNotifierProvider);
      expect(searchState.isCommitted, isTrue);

      // Shell reselect: same tab tapped again (goBranch initialLocation + reset).
      await tester.tap(_marketNavTab());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(_marketNavTab());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(appRouter.state.uri.path, kMarketBrowseRootPath);
      expect(find.text('Search market'), findsNothing);
      expect(find.text('Brand'), findsOneWidget);
      expect(find.text('Collectibles'), findsOneWidget);

      final container = ProviderScope.containerOf(
        tester.element(find.text('Collectibles')),
      );
      expect(
        container.read(marketSearchBrowseNotifierProvider).isCommitted,
        isFalse,
      );
      expect(container.read(marketSearchOverlayOpenProvider), isFalse);
    },
  );

  testWidgets(
    'Market tab reselect after back from search stays on browse root',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: _marketNavTestOverrides(),
          child: const BlindboxApp(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.text('Market'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      appRouter.push(kMarketSearchRoutePath);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      await tester.enterText(find.byType(TextField), 'molly');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 450));

      await tester.tap(find.byIcon(Icons.arrow_back_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(appRouter.state.uri.path, kMarketBrowseRootPath);

      await tester.tap(_marketNavTab());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(appRouter.state.uri.path, kMarketBrowseRootPath);
      expect(find.text('Search market'), findsNothing);
      expect(find.text('Brand'), findsOneWidget);
    },
  );

  testWidgets(
    'Market tab reselect from listing detail restores browse root',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: _marketNavTestOverrides(),
          child: const BlindboxApp(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.text('Market'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      appRouter.push('/market/listing/mock-listing-1');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(MarketDetailScreen), findsOneWidget);

      await tester.tap(_marketNavTab());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(appRouter.state.uri.path, kMarketBrowseRootPath);
      expect(find.byType(MarketDetailScreen), findsNothing);
      expect(find.text('Brand'), findsOneWidget);
      expect(find.text('Collectibles'), findsOneWidget);
    },
  );
}
