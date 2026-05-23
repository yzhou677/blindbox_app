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
    final prefix = providerId.name;
    final listingId = nativeId.isEmpty
        ? 'mkt-$prefix-${title.hashCode}'
        : 'mkt-$prefix-$nativeId';
    final priceUsd = double.tryParse(priceValue) ?? 0;
    final image = imageUrl.trim().isNotEmpty
        ? imageUrl.trim()
        : mockCollectibleArtUrl('$prefix-$listingId', 'e8eaf6');
    final url = listingUrl.trim();

    return MarketListing(
      id: listingId,
      providerId: providerId.wireName,
      providerListingId: nativeId.isEmpty ? null : nativeId,
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
    );
  }
}
