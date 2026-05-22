import 'package:blindbox_app/features/market/data/source/market_source.dart';
import 'package:blindbox_app/features/market/domain/market_provider_id.dart';
import 'package:blindbox_app/models/market_listing.dart';

/// Mercari browse stub — Phase 2 will add wire DTOs, cache, and network policy.
class MercariMarketSource implements MarketSource {
  const MercariMarketSource();

  @override
  MarketProviderId get providerId => MarketProviderId.mercari;

  @override
  Future<List<MarketListing>> fetchBrowseListings() async => const [];
}
