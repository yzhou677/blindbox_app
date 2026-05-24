import 'dart:convert';

import 'package:blindbox_app/features/market/data/cache/market_provider_browse_cache.dart';
import 'package:blindbox_app/features/market/data/datasource/market_gateway_client.dart';
import 'package:blindbox_app/features/market/data/datasource/mercari/mercari_browse_response_dto.dart';
import 'package:blindbox_app/features/market/data/datasource/mercari/mercari_listing_dto.dart';
import 'package:blindbox_app/features/market/data/datasource/mercari/mercari_gateway_exception.dart';
import 'package:blindbox_app/features/market/data/gateway/market_gateway_config.dart';
import 'package:blindbox_app/features/market/data/mappers/gateway_listing_mapper.dart';
import 'package:blindbox_app/features/market/data/source/market_source.dart';
import 'package:blindbox_app/features/market/domain/market_browse_page_result.dart';
import 'package:blindbox_app/features/market/domain/market_browse_query.dart';
import 'package:blindbox_app/features/market/domain/market_provider_id.dart';
import 'package:blindbox_app/models/market_listing.dart';
import 'package:flutter/foundation.dart';

/// Live eBay browse via Firebase gateway — query-driven, no eBay secrets in the app.
class EbayGatewayMarketSource implements MarketSource {
  EbayGatewayMarketSource({
    MarketGatewayClient? gateway,
    MarketProviderBrowseCache? cache,
  })  : _gateway = gateway ?? MarketGatewayClient(),
        _cache = cache ?? MarketProviderBrowseCache.instance;

  final MarketGatewayClient _gateway;
  final MarketProviderBrowseCache _cache;

  @override
  MarketProviderId get providerId => MarketProviderId.ebay;

  @override
  Future<List<MarketListing>> fetchBrowseListings() async {
    final page = await fetchFirstPage(const MarketBrowseQuery());
    return page.listings;
  }

  Future<MarketBrowsePageResult> fetchFirstPage(MarketBrowseQuery query) async {
    if (!MarketGatewayConfig.isActive) return MarketBrowsePageResult.empty;

    final uri = MarketGatewayConfig.gatewayUri;
    if (uri == null) return MarketBrowsePageResult.empty;

    final pageQuery = query.copyWith(
      limit: query.limit > 0 ? query.limit : MarketGatewayConfig.initialPageSize,
      clearCursor: true,
    );

    try {
      _clearFetchError();
      final response = await _gateway.fetchBrowse(
        baseUrl: uri,
        query: pageQuery,
      );
      return await _persistPage(
        query: pageQuery,
        items: response.items,
        nextCursor: response.nextCursor,
        hasMore: _pageHasMore(response),
        replace: true,
      );
    } on MercariGatewayException catch (e, st) {
      _recordFetchError(e);
      debugPrint('EbayGatewayMarketSource: gateway failed: $e\n$st');
      return _fallbackPage(pageQuery);
    } catch (e, st) {
      _recordFetchError(e);
      debugPrint('EbayGatewayMarketSource: fetch failed: $e\n$st');
      return _fallbackPage(pageQuery);
    }
  }

  Future<MarketBrowsePageResult> fetchNextPage(MarketBrowseQuery query) async {
    if (!MarketGatewayConfig.isActive) return MarketBrowsePageResult.empty;

    final batch = _cache.batchForQuery(
      providerId,
      query.signature,
    );
    if (batch == null) return MarketBrowsePageResult.empty;

    final cursor = batch.nextCursor;
    if (cursor == null || cursor.isEmpty || !batch.hasMore) {
      return MarketBrowsePageResult(
        listings: batch.listings,
        hasMore: false,
        fromCache: true,
      );
    }

    if (!_underTotalCap(batch.listings.length)) {
      return MarketBrowsePageResult(
        listings: batch.listings,
        hasMore: false,
        fromCache: true,
      );
    }

    final uri = MarketGatewayConfig.gatewayUri;
    if (uri == null) return _fallbackPage(query);

    final pageQuery = query.copyWith(
      limit: MarketGatewayConfig.pageSize,
      cursor: cursor,
    );

    try {
      final response = await _gateway.fetchBrowse(
        baseUrl: uri,
        query: pageQuery,
      );
      return await _persistPage(
        query: query,
        items: response.items,
        nextCursor: response.nextCursor,
        hasMore: _pageHasMore(response, existingCount: batch.listings.length),
        replace: false,
      );
    } on MercariGatewayException catch (e, st) {
      debugPrint('EbayGatewayMarketSource: next page failed: $e\n$st');
      return _fallbackPage(query);
    } catch (e, st) {
      debugPrint('EbayGatewayMarketSource: next page error: $e\n$st');
      return _fallbackPage(query);
    }
  }

  CachedBrowseBatch? cachedBatchFor(MarketBrowseQuery query) =>
      _cache.batchForQuery(providerId, query.signature);

  /// Memory batch first; on cold start hydrates per-query disk cache into memory.
  Future<CachedBrowseBatch?> resolveCachedBatchFor(MarketBrowseQuery query) async {
    var batch = cachedBatchFor(query);
    if (batch != null) return batch;

    await _cache.readStaleFromDiskForQuery(providerId, query.signature);
    batch = cachedBatchFor(query);
    if (batch == null) return null;
    if (!batch.isDiskStaleAcceptable(ttl: MarketGatewayConfig.diskStaleTtl)) {
      return null;
    }
    return batch;
  }

  void resetPaginationFor(MarketBrowseQuery query) =>
      _cache.clearQuery(providerId, query.signature);

  bool get hasMoreFromCache => false;

  static String? lastFetchError;

  static void _recordFetchError(Object e) => lastFetchError = e.toString();

  static void _clearFetchError() => lastFetchError = null;

  bool _pageHasMore(
    MercariBrowseResponseDto response, {
    int existingCount = 0,
  }) {
    if (!response.hasMore) return false;
    final cursor = response.nextCursor;
    if (cursor == null || cursor.isEmpty) return false;
    return _underTotalCap(existingCount + response.items.length);
  }

  bool _underTotalCap(int currentCount) =>
      currentCount < MarketGatewayConfig.maxLiveRows;

  Future<MarketBrowsePageResult> _persistPage({
    required MarketBrowseQuery query,
    required List<MercariListingDto> items,
    required String? nextCursor,
    required bool hasMore,
    required bool replace,
  }) async {
    final pageListings = items
        .map(
          (e) => e.toMarketListing(providerId: MarketProviderId.ebay),
        )
        .toList(growable: false);

    if (replace) {
      await _cache.writeForQuery(
        id: providerId,
        signature: query.signature,
        listings: pageListings,
        wireJson: _wireJson(items),
        nextCursor: nextCursor,
        hasMore: hasMore,
      );
    } else {
      await _cache.appendForQuery(
        id: providerId,
        signature: query.signature,
        newListings: pageListings,
        nextCursor: nextCursor,
        hasMore: hasMore,
      );
    }

    final batch = _cache.batchForQuery(providerId, query.signature)!;
    return MarketBrowsePageResult(
      listings: batch.listings,
      nextCursor: batch.nextCursor,
      hasMore: batch.hasMore,
    );
  }

  String _wireJson(List<MercariListingDto> items) {
    return jsonEncode({
      'items': [
        for (final item in items)
          {
            'id': item.id,
            'title': item.title,
            'price': {'value': item.priceValue, 'currency': item.currency},
            'image': {'imageUrl': item.imageUrl},
            'listingUrl': item.listingUrl,
          },
      ],
    });
  }

  Future<MarketBrowsePageResult> _fallbackPage(MarketBrowseQuery query) async {
    return MarketBrowsePageResult.empty;
  }
}
