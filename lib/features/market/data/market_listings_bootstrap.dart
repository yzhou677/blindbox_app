import 'package:blindbox_app/features/market/application/market_listing_identity_enricher.dart';
import 'package:blindbox_app/features/market/data/market_browse_listings_session.dart';
import 'package:blindbox_app/features/market/data/repository/market_listings_repository.dart';
import 'package:blindbox_app/features/market/data/source/default_market_sources.dart';

/// Loads browse listings once into [MarketBrowseListingsSession] (app + tests).
Future<void> bootstrapMarketBrowseListings() async {
  if (MarketBrowseListingsSession.instance.isInstalled) return;
  final repo = MarketListingsRepository(defaultMarketSources());
  final listings = enrichBrowseListingsIdentity(await repo.loadBrowseListings());
  MarketBrowseListingsSession.instance.install(listings);
}
