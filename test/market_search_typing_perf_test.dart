import 'package:blindbox_app/core/theme/app_theme.dart';
import 'package:blindbox_app/features/catalog/application/catalog_bundle_provider.dart';
import 'package:blindbox_app/features/catalog/catalog_bundle.dart';
import 'package:blindbox_app/features/collection/application/collection_notifier.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/market/application/market_search_browse_notifier.dart';
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
  await tester.pump(const Duration(milliseconds: 200));
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    MarketBrowseSearchScreen.debugBuildCount = 0;
  });

  testWidgets('typing does not rebuild screen before 400ms debounce', (tester) async {
    await _pumpMarketSearch(tester);
    MarketBrowseSearchScreen.debugBuildCount = 0;

    await tester.enterText(find.byType(TextField), 'labubu');
    await tester.pump();

    expect(
      MarketBrowseSearchScreen.debugBuildCount,
      0,
      reason: 'chrome-only typing must not rebuild MarketBrowseSearchScreen',
    );

    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();

    expect(
      MarketBrowseSearchScreen.debugBuildCount,
      greaterThan(0),
      reason: 'debounced commitQuery should rebuild via Riverpod',
    );
  });

  testWidgets('debounce remains 400ms before commitQuery', (tester) async {
    await _pumpMarketSearch(tester);

    await tester.enterText(find.byType(TextField), 'molly');
    await tester.pump();

    var container = ProviderScope.containerOf(
      tester.element(find.byType(MarketBrowseSearchScreen)),
    );
    var search = container.read(marketSearchBrowseNotifierProvider);
    expect(search.isCommitted, isFalse);

    await tester.pump(const Duration(milliseconds: 399));
    await tester.pump();
    search = container.read(marketSearchBrowseNotifierProvider);
    expect(search.isCommitted, isFalse);

    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();
    search = container.read(marketSearchBrowseNotifierProvider);
    expect(search.isCommitted, isTrue);
    expect(search.query, 'molly');
  });
}
