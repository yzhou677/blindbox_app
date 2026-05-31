import 'package:blindbox_app/core/navigation/shell_tab_reselect_bus.dart';
import 'package:blindbox_app/core/router/app_router.dart';
import 'package:blindbox_app/features/catalog/application/catalog_bundle_provider.dart';
import 'package:blindbox_app/features/catalog/catalog_seed_loader.dart';
import 'package:blindbox_app/features/collection/data/series_release_lookup.dart';
import 'package:blindbox_app/features/home/application/home_feed_provider.dart';
import 'package:blindbox_app/features/home/data/mock_latest_drops.dart';
import 'package:blindbox_app/features/market/application/active_market_browse_query.dart';
import 'package:blindbox_app/features/market/application/market_browse_intelligence_install.dart';
import 'package:blindbox_app/features/market/application/market_browse_root_navigation.dart';
import 'package:blindbox_app/features/market/application/market_search_browse_notifier.dart';
import 'package:blindbox_app/features/market/data/collectible_market_session.dart';
import 'package:blindbox_app/features/market/data/market_browse_listings_session.dart';
import 'package:blindbox_app/features/market/market_detail_screen.dart';
import 'package:blindbox_app/features/market/presentation/market_browse_search_screen.dart';
import 'package:blindbox_app/features/market/widgets/collectible_market_card.dart';
import 'package:blindbox_app/features/official_feed/application/official_feed_providers.dart';
import 'package:blindbox_app/main.dart';
import 'package:blindbox_app/models/collectible.dart';
import 'package:blindbox_app/models/market_listing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

List<Override> _marketNavTestOverrides() => [
  catalogBundleProvider.overrideWith(
    (_) async => const CatalogSeedBundle(
      brands: [],
      ips: [],
      series: [],
      figures: [],
    ),
  ),
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

Finder _collectionNavTab() => find.descendant(
      of: find.byType(NavigationBar),
      matching: find.text('Collection'),
    );

Future<void> _pumpBlindboxApp(WidgetTester tester) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: _marketNavTestOverrides(),
      child: const BlindboxApp(),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> _openMarketTab(WidgetTester tester) async {
  await tester.tap(find.text('Market'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
}

void _installMarketBrowseSearchFixture() {
  MarketBrowseListingsSession.instance.reset();
  CollectibleMarketSession.instance.reset();
  installMarketBrowseIntelligence([
    MarketListing(
      id: 'mkt-fixture-labubu',
      collectible: Collectible(
        id: 'mkt-fixture-labubu',
        name: 'Labubu Pink Vinyl Figure',
        series: 'Exciting Macaron',
        brand: 'POP MART',
        releaseDate: DateTime.utc(2026, 3, 20),
        imageUrl: 'https://example.com/labubu.png',
      ),
      currentPriceUsd: 42,
      priceChangePercent: 0,
      listingCount: 1,
    ),
  ]);
}

Future<void> _tapFirstMarketSearchPreviewSheet(WidgetTester tester) async {
  for (var attempt = 0; attempt < 30; attempt++) {
    await tester.pump(const Duration(milliseconds: 50));
    if (find.byType(CollectibleMarketCard).evaluate().isNotEmpty) break;
  }
  expect(find.byType(CollectibleMarketCard), findsWidgets);
  await tester.tap(find.byType(CollectibleMarketCard).first);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  expect(find.byType(BottomSheet), findsOneWidget);
}

Future<void> _openMarketSearchWithQuery(
  WidgetTester tester,
  String query,
) async {
  appRouter.push(kMarketSearchRoutePath);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.enterText(find.byType(TextField), query);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 450));
}

Future<void> _marketTabReselect(WidgetTester tester) async {
  await tester.tap(_marketNavTab());
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.tap(_marketNavTab());
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

void _expectBrowseChromeNotImmersive(ProviderContainer container) {
  expect(container.read(marketSearchOverlayOpenProvider), isFalse);
  expect(
    container.read(marketSearchBrowseNotifierProvider).isCommitted,
    isFalse,
  );
}

void _expectFullBrowseRoot({
  required ProviderContainer container,
  required String routePath,
}) {
  expect(routePath, kMarketBrowseRootPath);
  _expectBrowseChromeNotImmersive(container);
  expect(container.read(marketSearchBrowseNotifierProvider).query, isEmpty);
  expect(container.read(activeMarketBrowseQueryProvider).searchText, isEmpty);
}

/// After shell reselect, overlay session must clear before/at first root build.
Future<void> _assertBrowseChromeAfterFirstReselectPump(
  WidgetTester tester,
) async {
  await tester.tap(_marketNavTab());
  await tester.pump();
  final container = ProviderScope.containerOf(
    tester.element(find.byType(NavigationBar)),
  );
  _expectBrowseChromeNotImmersive(container);
  await tester.pump(const Duration(milliseconds: 400));
  expect(appRouter.state.uri.path, kMarketBrowseRootPath);
  expect(find.text('Brand'), findsOneWidget);
  expect(find.text('Collectibles'), findsOneWidget);
}

void _expectSearchSessionPreserved({
  required ProviderContainer container,
  required String expectedQuery,
}) {
  final search = container.read(marketSearchBrowseNotifierProvider);
  expect(search.isCommitted, isTrue);
  expect(search.query, expectedQuery);
  expect(container.read(marketSearchOverlayOpenProvider), isTrue);
  expect(
    container.read(activeMarketBrowseQueryProvider).searchText,
    expectedQuery,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ShellTabReselectBus.instance.clearMarketBrowseRootResetPending();
    ShellTabReselectBus.instance.reselectedBranch.value = null;
    _installMarketBrowseSearchFixture();
    appRouter.go('/collection');
  });

  tearDown(() {
    MarketBrowseListingsSession.instance.reset();
    CollectibleMarketSession.instance.reset();
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
    'scenario 1: search then listing then market reselect restores browse root',
    (WidgetTester tester) async {
      await _pumpBlindboxApp(tester);
      await _openMarketTab(tester);
      await _openMarketSearchWithQuery(tester, 'baby');

      final containerBefore = ProviderScope.containerOf(
        tester.element(find.byType(MarketBrowseSearchScreen)),
      );
      _expectSearchSessionPreserved(
        container: containerBefore,
        expectedQuery: 'baby',
      );

      appRouter.push('/market/listing/mock-listing-1');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(MarketDetailScreen), findsOneWidget);

      await _assertBrowseChromeAfterFirstReselectPump(tester);

      expect(find.byType(MarketDetailScreen), findsNothing);
      expect(find.text('Search market'), findsNothing);

      final container = ProviderScope.containerOf(
        tester.element(find.text('Collectibles')),
      );
      _expectFullBrowseRoot(
        container: container,
        routePath: appRouter.state.uri.path,
      );
    },
  );

  testWidgets(
    'scenario 2: search then preview sheet then market reselect restores browse root',
    (WidgetTester tester) async {
      await _pumpBlindboxApp(tester);
      await _openMarketTab(tester);
      await _openMarketSearchWithQuery(tester, 'labubu');
      await _tapFirstMarketSearchPreviewSheet(tester);

      await _assertBrowseChromeAfterFirstReselectPump(tester);

      expect(find.byType(BottomSheet), findsNothing);
      expect(find.text('Search market'), findsNothing);

      final container = ProviderScope.containerOf(
        tester.element(find.text('Collectibles')),
      );
      _expectFullBrowseRoot(
        container: container,
        routePath: appRouter.state.uri.path,
      );
    },
  );

  testWidgets(
    'scenario 3: search then collection then market preserves search session',
    (WidgetTester tester) async {
      await _pumpBlindboxApp(tester);
      await _openMarketTab(tester);
      await _openMarketSearchWithQuery(tester, 'baby');

      final searchElement = tester.element(find.byType(MarketBrowseSearchScreen));
      final containerBefore = ProviderScope.containerOf(searchElement);
      _expectSearchSessionPreserved(
        container: containerBefore,
        expectedQuery: 'baby',
      );

      await tester.tap(_collectionNavTab());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(appRouter.state.uri.path, '/collection');

      await tester.tap(_marketNavTab());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(appRouter.state.uri.path, kMarketSearchRoutePath);
      expect(find.text('Search market'), findsOneWidget);
      expect(find.byType(MarketBrowseSearchScreen), findsOneWidget);

      final containerAfter = ProviderScope.containerOf(
        tester.element(find.byType(MarketBrowseSearchScreen)),
      );
      _expectSearchSessionPreserved(
        container: containerAfter,
        expectedQuery: 'baby',
      );
      expect(find.text('Brand'), findsNothing);
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

      await _assertBrowseChromeAfterFirstReselectPump(tester);

      expect(find.byType(MarketDetailScreen), findsNothing);
      _expectFullBrowseRoot(
        container: ProviderScope.containerOf(
          tester.element(find.text('Collectibles')),
        ),
        routePath: appRouter.state.uri.path,
      );
    },
  );
}
