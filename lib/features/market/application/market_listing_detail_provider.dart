import 'package:blindbox_app/features/market/application/market_listings_providers.dart';
import 'package:blindbox_app/features/market/data/datasource/gateway_item_detail_dto.dart';
import 'package:blindbox_app/features/market/data/datasource/market_gateway_client.dart';
import 'package:blindbox_app/features/market/data/gateway/market_gateway_config.dart';
import 'package:blindbox_app/features/market/domain/market_listing_detail.dart';
import 'package:blindbox_app/features/market/domain/market_provider_id.dart';
import 'package:blindbox_app/features/market/utils/ebay_image_url.dart';
import 'package:blindbox_app/models/market_listing.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final marketGatewayClientProvider = Provider<MarketGatewayClient>((ref) {
  return MarketGatewayClient();
});

MarketListing? findMarketListingById(Ref ref, String listingId) {
  for (final listing in ref.watch(marketBrowseListingsProvider)) {
    if (listing.id == listingId) return listing;
  }
  return null;
}

/// Lazy gateway item detail for a browse row (live eBay only).
final marketListingDetailProvider =
    FutureProvider.autoDispose.family<MarketListingDetail?, String>(
  (ref, listingId) async {
    if (!MarketGatewayConfig.isActive) return null;

    final listing = findMarketListingById(ref, listingId);
    if (listing == null) return null;
    if (listing.providerId != MarketProviderId.ebay.wireName) return null;

    final nativeId = listing.providerListingId?.trim();
    if (nativeId == null || nativeId.isEmpty) return null;

    final baseUrl = MarketGatewayConfig.gatewayUri;
    if (baseUrl == null) return null;

    final client = ref.watch(marketGatewayClientProvider);
    final wire = await client.fetchItemDetail(
      baseUrl: baseUrl,
      itemId: ebayBrowseItemId(nativeId),
    );
    return wire == null ? null : _mapDetail(wire, listing);
  },
);

MarketListingDetail _mapDetail(GatewayItemDetailDto wire, MarketListing listing) {
  final feedback = wire.sellerFeedbackPercentage?.trim();
  final username = wire.sellerUsername?.trim();
  final sellerLine = username == null || username.isEmpty
      ? null
      : feedback == null || feedback.isEmpty
          ? username
          : '$username · $feedback% positive';

  final image = wire.imageUrl.trim().isNotEmpty
      ? upgradeEbayImageUrl(wire.imageUrl.trim(), size: EbayImageSize.detail)
      : upgradeEbayImageUrl(
          listing.collectible.imageUrl,
          size: EbayImageSize.detail,
        );

  final listingUrl = wire.listingUrl.trim().isNotEmpty
      ? wire.listingUrl.trim()
      : (listing.externalListingUrl ?? '');

  return MarketListingDetail(
    itemId: wire.itemId,
    title: wire.title,
    imageUrl: image,
    listingUrl: listingUrl,
    condition: wire.condition,
    quantityAvailable: wire.quantityAvailable,
    availabilityStatus: wire.availabilityStatus,
    shortDescription: wire.shortDescription,
    sellerLine: sellerLine,
    shippingSummary: wire.shippingSummary,
  );
}

/// User-facing quantity / stock line for listing detail.
String? formatMarketListingQuantityLine(MarketListingDetail detail) {
  final status = detail.availabilityStatus?.trim().toUpperCase();
  if (status == 'OUT_OF_STOCK') return 'Out of stock';

  final qty = detail.quantityAvailable;
  if (qty != null) {
    if (qty == 0) return 'Out of stock';
    if (qty == 1) return '1 available';
    return '$qty available';
  }

  return switch (status) {
    'IN_STOCK' => 'In stock',
    'LIMITED_STOCK' => 'Limited stock',
    _ => null,
  };
}
