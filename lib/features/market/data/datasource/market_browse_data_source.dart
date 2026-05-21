import 'package:blindbox_app/features/market/data/dto/ebay_item_summary_dto.dart';

/// Remote (or fake-remote) browse feed. Implementations parse wire JSON into [EbayItemSummaryDto].
abstract class MarketBrowseDataSource {
  Future<List<EbayItemSummaryDto>> fetchBrowseSummaries();
}
