import 'package:blindbox_app/features/market/domain/market_provider_id.dart';
import 'package:blindbox_app/models/market_listing.dart';

/// Provider boundary for market browse feeds. Wire DTOs stay inside implementations.
abstract class MarketSource {
  MarketProviderId get providerId;

  Future<List<MarketListing>> fetchBrowseListings();
}

/// Legacy alias — prefer [MarketSource].
typedef MarketBrowseDataSource = MarketSource;
