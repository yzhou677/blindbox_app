import 'dart:convert';

import 'package:blindbox_app/features/market/data/cache/market_provider_browse_cache.dart';
import 'package:blindbox_app/features/market/data/datasource/mercari/mercari_gateway_client.dart';
import 'package:blindbox_app/features/market/data/datasource/mercari/mercari_gateway_exception.dart';
import 'package:blindbox_app/features/market/data/mappers/mercari_listing_mapper.dart';
import 'package:blindbox_app/features/market/data/sandbox/market_sandbox_config.dart';
import 'package:blindbox_app/features/market/data/source/market_source.dart';
import 'package:blindbox_app/features/market/domain/market_provider_id.dart';
import 'package:blindbox_app/models/market_listing.dart';
import 'package:flutter/foundation.dart';

/// Live Mercari browse via gateway — feature-flagged; returns cached rows on failure.
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
    if (!MarketSandboxConfig.isActive) return const [];

    final uri = MarketSandboxConfig.gatewayUri;
    if (uri == null) return const [];

    try {
      final response = await _gateway.fetchBrowse(
        baseUrl: uri,
        limit: MarketSandboxConfig.maxMercariItems,
      );
      final listings = response.items
          .map((e) => e.toMarketListing())
          .toList(growable: false);
      final wireJson = jsonEncode({
        'items': [
          for (final item in response.items)
            {
              'id': item.id,
              'title': item.title,
              'price': {'value': item.priceValue, 'currency': item.currency},
              'image': {'imageUrl': item.imageUrl},
              'listingUrl': item.listingUrl,
            },
        ],
      });
      await _cache.write(
        id: providerId,
        listings: listings,
        wireJson: wireJson,
      );
      return listings;
    } on MercariGatewayException catch (e, st) {
      debugPrint('MercariSandboxMarketSource: gateway failed: $e\n$st');
      return await _fallbackCached();
    } catch (e, st) {
      debugPrint('MercariSandboxMarketSource: fetch failed: $e\n$st');
      return await _fallbackCached();
    }
  }

  Future<List<MarketListing>> _fallbackCached() async {
    final stale = _cache.readStale(providerId, allowExpired: true) ??
        await _cache.readStaleFromDisk(providerId);
    return stale ?? const [];
  }
}
