@Tags(['network'])
library;

import 'package:blindbox_app/core/navigation/shell_tab_reselect_bus.dart';
import 'package:blindbox_app/core/router/app_router.dart';
import 'package:blindbox_app/features/catalog/application/catalog_bundle_provider.dart';
import 'package:blindbox_app/features/catalog/catalog_seed_loader.dart';
import 'package:blindbox_app/features/collection/application/collection_notifier.dart';
import 'package:blindbox_app/features/collection/data/series_release_lookup.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/home/application/home_feed_provider.dart';
import 'package:blindbox_app/features/home/data/mock_latest_drops.dart';
import 'package:blindbox_app/features/market/application/market_search_browse_notifier.dart';
import 'package:blindbox_app/features/market/data/gateway/market_gateway_config.dart';
import 'package:blindbox_app/features/market/debug/market_browse_state_diagnostic.dart';
import 'package:blindbox_app/features/market/market_detail_screen.dart';
import 'package:blindbox_app/features/market/presentation/market_browse_search_screen.dart';
import 'package:blindbox_app/features/market/widgets/collectible_market_card.dart';
import 'package:blindbox_app/features/official_feed/application/official_feed_providers.dart';
import 'package:blindbox_app/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

final class _EmptyCollectionNotifier extends CollectionNotifier {
  @override
  CollectionSnapshot build() =>
      const CollectionSnapshot(shelfSeries: [], figureStates: {});
}

/// Gateway audit: Dora search → listing → Market tab reselect.
///
/// Run (debug + gateway):
/// ```
/// flutter test test/market_gateway_dora_reselect_audit_test.dart ^
///   --dart-define=MARKET_GATEWAY_EBAY=true ^
///   --dart-define=MARKET_GATEWAY_BASE_URL=https://us-central1-blindbox-collection.cloudfunctions.net/market
/// ```
///
/// Captures `browseSnapshot[...]` lines to stdout (same tags as device logcat).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('audit: gateway isActive flag at compile time', () {
    // ignore: avoid_print
    print(
      'AUDIT gateway compile-time isActive=${MarketGatewayConfig.isActive} '
      'enableEbay=${MarketGatewayConfig.enableEbayGateway} '
      'baseUrlEmpty=${MarketGatewayConfig.gatewayBaseUrl.isEmpty}',
    );
  });

  testWidgets('audit: Dora flow snapshots when gateway active', (
    WidgetTester tester,
  ) async {
    if (!MarketGatewayConfig.isActive) {
      // ignore: avoid_print
      print(
        'AUDIT SKIP: gateway inactive in this test run — '
        're-run with MARKET_GATEWAY_EBAY and MARKET_GATEWAY_BASE_URL',
      );
      return;
    }

    SharedPreferences.setMockInitialValues({});
    ShellTabReselectBus.instance.clearMarketBrowseRootResetPending();
    ShellTabReselectBus.instance.reselectedBranch.value = null;

    late ProviderContainer container;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          collectionNotifierProvider.overrideWith(_EmptyCollectionNotifier.new),
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
              trending:
                  mockSeriesReleases.skip(1).take(4).toList(growable: false),
            ),
          ),
          officialFeedListProvider.overrideWith((_) async => const []),
          seriesReleaseLookupProvider.overrideWithValue(mockSeriesReleaseByDropId),
        ],
        child: Builder(
          builder: (context) {
            container = ProviderScope.containerOf(context);
            return const BlindboxApp();
          },
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));

    MarketBrowseStateDiagnostic.logContainer(
      container,
      phase: 'audit_start',
      routePath: appRouter.state.uri.path,
    );

    await tester.tap(find.text('Market'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));

    appRouter.push('/market/search');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    await tester.enterText(find.byType(TextField), 'dora');
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(seconds: 3));

    MarketBrowseStateDiagnostic.logContainer(
      container,
      phase: 'audit_after_dora_type',
      routePath: appRouter.state.uri.path,
    );

    final search = container.read(marketSearchBrowseNotifierProvider);
    if (!search.isCommitted) {
      // ignore: avoid_print
      print('AUDIT ABORT: dora search never committed (network/gateway?)');
      return;
    }

    final cards = find.byType(CollectibleMarketCard);
    if (cards.evaluate().isEmpty) {
      MarketBrowseStateDiagnostic.logContainer(
        container,
        phase: 'audit_no_search_cards',
        routePath: appRouter.state.uri.path,
      );
      // ignore: avoid_print
      print('AUDIT ABORT: no CollectibleMarketCard for dora');
      return;
    }

    await tester.tap(cards.first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));

    final listingId = _firstListingIdFromCard(tester, cards.first);
    if (listingId == null) {
      // ignore: avoid_print
      print('AUDIT ABORT: could not resolve listing id from card');
      return;
    }

    appRouter.push('/market/listing/$listingId');
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    expect(find.byType(MarketDetailScreen), findsOneWidget);

    MarketBrowseStateDiagnostic.logContainer(
      container,
      phase: 'audit_listing_detail',
      routePath: appRouter.state.uri.path,
    );

    final marketTab = find.descendant(
      of: find.byType(NavigationBar),
      matching: find.text('Market'),
    );
    await tester.tap(marketTab);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(marketTab);
    await tester.pump();
    await tester.pump(const Duration(seconds: 4));

    MarketBrowseStateDiagnostic.logContainer(
      container,
      phase: 'audit_after_market_reselect',
      routePath: appRouter.state.uri.path,
    );

    expect(appRouter.state.uri.path, '/market');
  });
}

String? _firstListingIdFromCard(WidgetTester tester, Finder card) {
  try {
    final cardWidget = tester.widget<CollectibleMarketCard>(card);
    final rep = cardWidget.snapshot.listingIds;
    if (rep.isEmpty) return null;
    return rep.first;
  } catch (_) {
    return null;
  }
}
