import 'package:blindbox_app/features/market/data/dto/ebay_item_summary_dto.dart';
import 'package:http/http.dart' as http;

/// Real eBay Browse API (or compatible gateway). Wire when OAuth + endpoints are available.
///
/// Not a [MarketSource] — [EbayMarketSource] maps DTOs to [MarketListing]. This class is
/// wire-level only. Today [fetchBrowseSummaries] throws until response mapping exists.
class EbayHttpBrowseDataSource {
  EbayHttpBrowseDataSource({
    required this.client,
    this.browseUri,
  });

  final http.Client client;
  final Uri? browseUri;

  Future<List<EbayItemSummaryDto>> fetchBrowseSummaries() async {
    final uri = browseUri;
    if (uri == null) {
      throw UnsupportedError(
        'eBay Browse is not configured (browseUri is null). Use AssetMarketSource for demos.',
      );
    }
    final response = await client.get(uri);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        'eBay Browse request failed: ${response.statusCode} ${response.reasonPhrase}',
      );
    }
    throw UnimplementedError(
      'Map eBay Browse JSON to List<EbayItemSummaryDto> when API contract is finalized.',
    );
  }
}
