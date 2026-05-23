import 'package:blindbox_app/features/market/data/datasource/ebay_browse_wire_loader.dart';
import 'package:blindbox_app/features/market/data/mappers/ebay_item_summary_mapper.dart';
import 'package:blindbox_app/features/market/data/source/market_source.dart';
import 'package:blindbox_app/features/market/domain/market_provider_id.dart';
import 'package:blindbox_app/models/market_listing.dart';

/// Offline-first bundled browse feed (provider-neutral demo JSON).
class AssetMarketSource implements MarketSource {
  AssetMarketSource({
    this.assetPath = 'assets/market/fake_market_browse_items.json',
  });

  final String assetPath;

  @override
  MarketProviderId get providerId => MarketProviderId.mock;

  @override
  Future<List<MarketListing>> fetchBrowseListings() async {
    final dtos = await loadEbayShapedBrowseAsset(assetPath);
    return dtos
        .map((e) => e.toMarketListing(providerId: providerId))
        .toList(growable: false);
  }
}
