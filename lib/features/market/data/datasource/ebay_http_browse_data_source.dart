import 'package:blindbox_app/features/market/data/datasource/market_browse_data_source.dart';
import 'package:blindbox_app/features/market/data/dto/ebay_item_summary_dto.dart';
import 'package:http/http.dart' as http;

/// Real eBay Browse API (or compatible gateway). Wire when OAuth + endpoints are available.
///
/// Today this is a **skeleton**: [fetchBrowseSummaries] throws until response mapping exists.
class EbayHttpBrowseDataSource implements MarketBrowseDataSource {
  EbayHttpBrowseDataSource({
    required this.client,
    this.browseUri,
  });

  final http.Client client;
  final Uri? browseUri;

  @override
  Future<List<EbayItemSummaryDto>> fetchBrowseSummaries() async {
    final uri = browseUri;
    if (uri == null) {
      throw UnsupportedError(
        'eBay Browse is not configured (browseUri is null). Use FakeEbayBrowseDataSource for demos.',
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
