import 'package:blindbox_app/features/market/data/datasource/ebay_browse_wire_loader.dart';
import 'package:blindbox_app/features/market/data/datasource/ebay_http_browse_data_source.dart';
import 'package:blindbox_app/features/market/data/mappers/ebay_item_summary_mapper.dart';
import 'package:blindbox_app/features/market/data/source/market_source.dart';
import 'package:blindbox_app/features/market/domain/market_provider_id.dart';
import 'package:blindbox_app/models/market_listing.dart';
import 'package:http/http.dart' as http;

/// eBay browse adapter — not registered in [defaultMarketSources] until Phase 2.
class EbayMarketSource implements MarketSource {
  EbayMarketSource({
    this.assetPath,
    EbayHttpBrowseDataSource? httpDataSource,
    http.Client? client,
    Uri? browseUri,
  }) : _http = httpDataSource ??
            (browseUri != null || client != null
                ? EbayHttpBrowseDataSource(
                    client: client ?? http.Client(),
                    browseUri: browseUri,
                  )
                : null);

  final String? assetPath;
  final EbayHttpBrowseDataSource? _http;

  @override
  MarketProviderId get providerId => MarketProviderId.ebay;

  @override
  Future<List<MarketListing>> fetchBrowseListings() async {
    final path = assetPath;
    if (path != null && path.isNotEmpty) {
      final dtos = await loadEbayShapedBrowseAsset(path);
      return dtos
          .map((e) => e.toMarketListing(providerId: providerId))
          .toList(growable: false);
    }
    final httpSource = _http;
    if (httpSource != null) {
      final dtos = await httpSource.fetchBrowseSummaries();
      return dtos
          .map((e) => e.toMarketListing(providerId: providerId))
          .toList(growable: false);
    }
    return const [];
  }
}
