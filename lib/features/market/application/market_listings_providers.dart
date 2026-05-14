import 'package:blindbox_app/features/market/data/datasource/fake_ebay_browse_data_source.dart';
import 'package:blindbox_app/features/market/data/datasource/market_browse_data_source.dart';
import 'package:blindbox_app/features/market/data/market_browse_listings_session.dart';
import 'package:blindbox_app/features/market/data/repository/market_listings_repository.dart';
import 'package:blindbox_app/models/market_listing.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Demo datasource (swap for [EbayHttpBrowseDataSource] when eBay is wired).
final marketBrowseDataSourceProvider = Provider<MarketBrowseDataSource>((ref) {
  return FakeEbayBrowseDataSource();
});

final marketListingsRepositoryProvider = Provider<MarketListingsRepository>((ref) {
  return MarketListingsRepository(ref.watch(marketBrowseDataSourceProvider));
});

/// Sync read of bootstrapped browse listings (see [bootstrapMarketBrowseListings]).
final marketBrowseListingsProvider = Provider<List<MarketListing>>((ref) {
  return MarketBrowseListingsSession.instance.list;
});

/// Pull-to-refresh / manual reload: re-fetch from datasource into session.
Future<void> refreshMarketBrowseListings(WidgetRef ref) async {
  final next = await ref.read(marketListingsRepositoryProvider).loadBrowseListings();
  MarketBrowseListingsSession.instance.install(next);
  ref.invalidate(marketBrowseListingsProvider);
}
