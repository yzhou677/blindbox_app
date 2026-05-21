import 'package:blindbox_app/features/market/data/datasource/fake_ebay_browse_data_source.dart';
import 'package:blindbox_app/features/market/data/market_browse_listings_session.dart';
import 'package:blindbox_app/features/market/data/repository/market_listings_repository.dart';

/// Loads browse listings once into [MarketBrowseListingsSession] (app + tests).
Future<void> bootstrapMarketBrowseListings() async {
  if (MarketBrowseListingsSession.instance.isInstalled) return;
  final repo = MarketListingsRepository(FakeEbayBrowseDataSource());
  final listings = await repo.loadBrowseListings();
  MarketBrowseListingsSession.instance.install(listings);
}
