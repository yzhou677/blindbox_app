import 'package:blindbox_app/core/theme/app_theme.dart';
import 'package:blindbox_app/features/catalog/application/catalog_bundle_provider.dart';
import 'package:blindbox_app/features/catalog/catalog_seed_loader.dart';
import 'package:blindbox_app/features/collection/application/collection_notifier.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/market/application/active_market_browse_query.dart';
import 'package:blindbox_app/features/market/application/market_feed_browse_notifier.dart';
import 'package:blindbox_app/features/market/catalog/market_taxonomy.dart';
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('search nommi uses Any Brand and Any IP while feed filters stay', (
    tester,
  ) async {
    final container = ProviderContainer(
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
    );
    addTearDown(container.dispose);

    container.read(marketFeedBrowseNotifierProvider.notifier)
      ..setBrand('pop_mart')
      ..setIp('pucky');

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const MarketBrowseSearchScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'nommi');
    await tester.pump(const Duration(milliseconds: 450));

    final feed = container.read(marketFeedBrowseNotifierProvider);
    expect(feed.brandId, 'pop_mart');
    expect(feed.ipId, 'pucky');

    final query = container.read(activeMarketBrowseQueryProvider);
    expect(query.brandId, MarketTaxonomyIds.anyBrand);
    expect(query.ipId, MarketTaxonomyIds.anyIp);
    expect(query.searchText, 'nommi');
  });
}
