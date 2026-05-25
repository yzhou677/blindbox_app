import 'package:blindbox_app/features/market/utils/ebay_image_url.dart';
import 'package:blindbox_app/features/home/data/mock_latest_drops.dart';
import 'package:blindbox_app/features/market/data/datasource/mercari/mercari_listing_dto.dart';
import 'package:blindbox_app/features/market/domain/market_provider_id.dart';
import 'package:blindbox_app/models/collectible.dart';
import 'package:blindbox_app/models/market_listing.dart';

extension GatewayListingDtoMapper on MercariListingDto {
  MarketListing toMarketListing({
    MarketProviderId providerId = MarketProviderId.mercari,
  }) {
    final nativeId = id.trim();
    final stableNativeId = providerId == MarketProviderId.ebay
        ? _ebayStableNativeId(nativeId)
        : nativeId;
    final prefix = providerId.name;
    final listingId = stableNativeId.isEmpty
        ? 'mkt-$prefix-${title.hashCode}'
        : 'mkt-$prefix-$stableNativeId';
    final priceUsd = double.tryParse(priceValue) ?? 0;
    final image = imageUrl.trim().isNotEmpty
        ? upgradeEbayImageUrl(imageUrl.trim())
        : mockCollectibleArtUrl('$prefix-$listingId', 'e8eaf6');
    final url = listingUrl.trim();
    final created = itemCreationDate?.trim();
    final seller = sellerUsername?.trim();

    return MarketListing(
      id: listingId,
      providerId: providerId.wireName,
      providerListingId: stableNativeId.isEmpty ? null : stableNativeId,
      externalListingUrl: url.isEmpty ? null : url,
      taxonomyBrandId: null,
      taxonomyIpId: null,
      collectible: Collectible(
        id: listingId,
        name: title.trim().isEmpty ? 'Listing' : title.trim(),
        series: '',
        brand: '',
        releaseDate: DateTime.utc(2026),
        imageUrl: image,
      ),
      currentPriceUsd: priceUsd,
      priceChangePercent: 0,
      listingCount: 1,
      sellerUsername: seller != null && seller.isNotEmpty ? seller : null,
      itemCreationDate:
          created == null || created.isEmpty ? null : DateTime.tryParse(created),
    );
  }
}

/// eBay Browse uses `v1|{legacyItemId}|0` — stable id for dedupe and listing keys.
String _ebayStableNativeId(String itemId) {
  final parts = itemId.split('|');
  if (parts.length >= 2 && parts.first == 'v1') {
    final legacy = parts[1].trim();
    if (legacy.isNotEmpty) return legacy;
  }
  return itemId;
}
