import 'package:blindbox_app/features/market/data/datasource/market_browse_data_source.dart';
import 'package:blindbox_app/features/market/data/mappers/ebay_item_summary_mapper.dart';
import 'package:blindbox_app/models/market_listing.dart';

/// Browse listings: datasource (DTO) → domain [MarketListing].
class MarketListingsRepository {
  MarketListingsRepository(this._dataSource);

  final MarketBrowseDataSource _dataSource;

  Future<List<MarketListing>> loadBrowseListings() async {
    final dtos = await _dataSource.fetchBrowseSummaries();
    return dtos.map((e) => e.toMarketListing()).toList(growable: false);
  }
}
