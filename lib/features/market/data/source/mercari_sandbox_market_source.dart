import 'dart:convert';

import 'package:blindbox_app/features/market/data/cache/market_provider_browse_cache.dart';
import 'package:blindbox_app/features/market/data/datasource/mercari/mercari_browse_response_dto.dart';
import 'package:blindbox_app/features/market/data/datasource/mercari/mercari_gateway_client.dart';
import 'package:blindbox_app/features/market/data/datasource/mercari/mercari_gateway_exception.dart';
import 'package:blindbox_app/features/market/data/datasource/mercari/mercari_listing_dto.dart';
import 'package:blindbox_app/features/market/data/mappers/mercari_listing_mapper.dart';
import 'package:blindbox_app/features/market/data/sandbox/market_sandbox_config.dart';
import 'package:blindbox_app/features/market/data/source/market_source.dart';
import 'package:blindbox_app/features/market/domain/market_browse_page_result.dart';
import 'package:blindbox_app/features/market/domain/market_provider_id.dart';
import 'package:blindbox_app/models/market_listing.dart';
import 'package:flutter/foundation.dart';

/// Live Mercari browse via gateway — pagination, retry, stale cache recovery.
class MercariSandboxMarketSource implements MarketSource {
  MercariSandboxMarketSource({
    MercariGatewayClient? gateway,
    MarketProviderBrowseCache? cache,
  })  : _gateway = gateway ?? MercariGatewayClient(),
        _cache = cache ?? MarketProviderBrowseCache.instance;

  final MercariGatewayClient _gateway;
  final MarketProviderBrowseCache _cache;

  @override
  MarketProviderId get providerId => MarketProviderId.mercari;

  @override
  Future<List<MarketListing>> fetchBrowseListings() async {
    final page = await fetchFirstPage();
    return page.listings;
  }

  /// First page — replaces accumulated Mercari rows.
  Future<MarketBrowsePageResult> fetchFirstPage() async {
    if (!MarketSandboxConfig.isActive) return MarketBrowsePageResult.empty;

    final uri = MarketSandboxConfig.gatewayUri;
    if (uri == null) return MarketBrowsePageResult.empty;

    try {
      _clearFetchError();
      final response = await _gateway.fetchBrowse(
        baseUrl: uri,
        limit: MarketSandboxConfig.pageSize,
      );
      return await _persistPage(
        items: response.items,
        nextCursor: response.nextCursor,
        hasMore: _pageHasMore(response),
        replace: true,
      );
    } on MercariGatewayException catch (e, st) {
      _recordFetchError(e);
      debugPrint('MercariSandboxMarketSource: gateway failed: $e\n$st');
      return _fallbackPage();
    } catch (e, st) {
      _recordFetchError(e);
      debugPrint('MercariSandboxMarketSource: fetch failed: $e\n$st');
      return _fallbackPage();
    }
  }

  /// Appends the next gateway page when a continuation cursor exists.
  Future<MarketBrowsePageResult> fetchNextPage() async {
    if (!MarketSandboxConfig.isActive) return MarketBrowsePageResult.empty;

    final batch = _cache.batchFor(providerId);
    if (batch == null) return fetchFirstPage();

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

    final uri = MarketSandboxConfig.gatewayUri;
    if (uri == null) return _fallbackPage();

    try {
      final response = await _gateway.fetchBrowse(
        baseUrl: uri,
        limit: MarketSandboxConfig.pageSize,
        cursor: cursor,
      );
      return await _persistPage(
        items: response.items,
        nextCursor: response.nextCursor,
        hasMore: _pageHasMore(response, existingCount: batch.listings.length),
        replace: false,
      );
    } on MercariGatewayException catch (e, st) {
      debugPrint('MercariSandboxMarketSource: next page failed: $e\n$st');
      return _fallbackPage();
    } catch (e, st) {
      debugPrint('MercariSandboxMarketSource: next page error: $e\n$st');
      return _fallbackPage();
    }
  }

  bool get hasMoreFromCache => _cache.batchFor(providerId)?.hasMore ?? false;

  void resetPagination() => _cache.clear(providerId);

  /// Set when [fetchFirstPage] / [fetchNextPage] catch a failure (for sandbox diagnostics).
  static String? lastFetchError;

  static void _recordFetchError(Object e) {
    lastFetchError = e.toString();
  }

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
      currentCount < MarketSandboxConfig.maxMercariTotalRows;

  Future<MarketBrowsePageResult> _persistPage({
    required List<MercariListingDto> items,
    required String? nextCursor,
    required bool hasMore,
    required bool replace,
  }) async {
    final pageListings =
        items.map((e) => e.toMarketListing()).toList(growable: false);

    if (replace) {
      await _cache.write(
        id: providerId,
        listings: pageListings,
        wireJson: _wireJson(items),
        nextCursor: nextCursor,
        hasMore: hasMore,
      );
    } else {
      await _cache.append(
        id: providerId,
        newListings: pageListings,
        nextCursor: nextCursor,
        hasMore: hasMore,
      );
    }

    final batch = _cache.batchFor(providerId)!;
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

  Future<MarketBrowsePageResult> _fallbackPage() async {
    final stale = _cache.readStale(providerId, allowExpired: true) ??
        await _cache.readStaleFromDisk(providerId);
    final listings = stale ?? const [];
    final batch = _cache.batchFor(providerId);
    return MarketBrowsePageResult(
      listings: listings,
      nextCursor: batch?.nextCursor,
      hasMore: batch?.hasMore ?? false,
      fromCache: true,
    );
  }
}
