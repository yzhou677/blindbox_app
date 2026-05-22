import 'package:blindbox_app/features/home/data/mock_latest_drops.dart';
import 'package:blindbox_app/features/market/data/dto/ebay_item_summary_dto.dart';
import 'package:blindbox_app/features/market/domain/market_provider_id.dart';
import 'package:blindbox_app/features/market/taxonomy/taxonomy_resolver.dart';
import 'package:blindbox_app/models/collectible.dart';
import 'package:blindbox_app/models/market_listing.dart';
import 'package:flutter/material.dart';

extension EbayItemSummaryDtoMapper on EbayItemSummaryDto {
  MarketListing toMarketListing({
    MarketProviderId providerId = MarketProviderId.ebay,
  }) {
    const resolver = TitleTaxonomyResolver();
    final taxonomy = resolver.resolve(title);
    String? taxonomyBrandId;
    String? taxonomyIpId;
    if (taxonomy.ipId != null &&
        taxonomy.brandId != null &&
        taxonomy.confidence >= TitleTaxonomyResolver.minConfidenceForTaxonomyIds) {
      taxonomyBrandId = taxonomy.brandId;
      taxonomyIpId = taxonomy.ipId;
    } else if (taxonomy.ipId == null &&
        taxonomy.brandId != null &&
        taxonomy.confidence >= TitleTaxonomyResolver.minConfidenceForBrandOnly) {
      taxonomyBrandId = taxonomy.brandId;
      taxonomyIpId = null;
    }

    final priceUsd = double.tryParse(priceValue) ?? 0;
    final release = DateTime.tryParse(appReleaseDateIso) ?? DateTime.utc(2026);
    final image = imageUrl.trim().isNotEmpty
        ? imageUrl
        : mockCollectibleArtUrl(appImageSeed, appImageTintHex);
    final webUrl = itemWebUrl.trim();
    final nativeId = itemId.trim();
    return MarketListing(
      id: appListingId,
      providerId: providerId.wireName,
      providerListingId: nativeId.isEmpty ? null : nativeId,
      externalListingUrl: webUrl.isEmpty ? null : webUrl,
      taxonomyBrandId: taxonomyBrandId,
      taxonomyIpId: taxonomyIpId,
      collectible: Collectible(
        id: appListingId,
        name: title,
        series: appCollectibleSeries,
        brand: appCollectibleBrand,
        releaseDate: release,
        imageUrl: image,
        shelfAccent: _colorFromHex(appShelfAccentHex),
      ),
      currentPriceUsd: priceUsd,
      priceChangePercent: appPriceChangePercent,
      listingCount: appListingCount,
      isTrending: appIsTrending,
      watchingCount: appWatchingCount,
      hasSecretFigure: appHasSecretFigure,
      isHardToFind: appIsHardToFind,
    );
  }
}

Color _colorFromHex(String hex) {
  var h = hex.replaceFirst('#', '');
  if (h.length == 6) {
    h = 'FF$h';
  }
  return Color(int.parse(h, radix: 16));
}
