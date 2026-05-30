@Tags(['network'])
library;

import 'package:blindbox_app/core/theme/app_theme.dart';
import 'package:blindbox_app/features/catalog/application/catalog_bundle_provider.dart';
import 'package:blindbox_app/features/catalog/catalog_seed_loader.dart';
import 'package:blindbox_app/features/collection/application/collection_notifier.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/market/application/market_live_browse_controller.dart';
import 'package:blindbox_app/features/market/data/gateway/market_gateway_config.dart';
import 'package:blindbox_app/features/market/presentation/market_browse_search_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

final class _EmptyCollectionNotifier extends CollectionNotifier {
  @override
  CollectionSnapshot build() =>
      const CollectionSnapshot(shelfSeries: [], figureStates: {});
}

/// Exercises live gateway search for "zor" and leaves [MarketSearch] traces in test output.
/// Run:
/// flutter test test/market_search_anr_repro_test.dart \
///   --dart-define=MARKET_GATEWAY_EBAY=true \
///   --dart-define=MARKET_GATEWAY_BASE_URL=https://us-central1-blindbox-collection.cloudfunctions.net/market
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('live gateway search zor — trace timeline', (tester) async {
    if (!MarketGatewayConfig.isActive) {
      // ignore: avoid_print
      print(
        '[MarketSearchRepro] SKIP: gateway inactive — pass MARKET_GATEWAY_EBAY '
        'and MARKET_GATEWAY_BASE_URL dart-defines',
      );
      return;
    }

    SharedPreferences.setMockInitialValues({});
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

    await tester.enterText(find.byType(TextField), 'zor');
    await tester.pump(const Duration(milliseconds: 450));

  // Allow network + commits + rebuilds (40 × 500ms = 20s max wait).
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 500));
      if (find.text('No matches for that search.').evaluate().isNotEmpty &&
          i > 2) {
        // ignore: avoid_print
        print('[MarketSearchRepro] empty UI visible at pump=$i');
      }
    }

    expect(find.text('No matches for that search.'), findsOneWidget);
  }, timeout: const Timeout(Duration(seconds: 45)));
}
