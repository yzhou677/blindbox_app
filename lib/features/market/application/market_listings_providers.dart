import 'package:blindbox_app/features/market/application/market_listing_identity_enricher.dart';
import 'package:blindbox_app/features/market/data/market_browse_listings_session.dart';
import 'package:blindbox_app/features/market/data/repository/market_listings_repository.dart';
import 'package:blindbox_app/features/market/data/source/default_market_sources.dart';
import 'package:blindbox_app/features/market/data/source/market_source.dart';
import 'package:blindbox_app/models/market_listing.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final marketSourcesProvider = Provider<List<MarketSource>>((ref) {
  return defaultMarketSources();
});

final marketListingsRepositoryProvider = Provider<MarketListingsRepository>((ref) {
  return MarketListingsRepository(ref.watch(marketSourcesProvider));
});

/// Sync read of bootstrapped browse listings (see [bootstrapMarketBrowseListings]).
final marketBrowseListingsProvider = Provider<List<MarketListing>>((ref) {
  return MarketBrowseListingsSession.instance.list;
});

/// Pull-to-refresh / manual reload: re-fetch from sources into session.
Future<void> refreshMarketBrowseListings(WidgetRef ref) async {
  final next = enrichBrowseListingsIdentity(
    await ref.read(marketListingsRepositoryProvider).loadBrowseListings(),
  );
  MarketBrowseListingsSession.instance.install(next);
  ref.invalidate(marketBrowseListingsProvider);
}
