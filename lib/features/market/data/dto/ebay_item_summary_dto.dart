import 'package:flutter/foundation.dart';

/// eBay Browse–style item summary (wire shape). Extended fields carry app-only catalog data.
@immutable
class EbayItemSummaryDto {
  const EbayItemSummaryDto({
    required this.itemId,
    required this.title,
    required this.priceValue,
    required this.currency,
    required this.imageUrl,
    required this.condition,
    required this.itemWebUrl,
    required this.appListingId,
    required this.appTaxonomyBrandId,
    this.appTaxonomyIpId,
    required this.appCollectibleSeries,
    required this.appCollectibleBrand,
    required this.appReleaseDateIso,
    required this.appImageSeed,
    required this.appImageTintHex,
    required this.appShelfAccentHex,
    required this.appPriceChangePercent,
    required this.appListingCount,
    required this.appIsTrending,
    required this.appWatchingCount,
    required this.appHasSecretFigure,
    required this.appIsHardToFind,
  });

  final String itemId;
  final String title;
  final String priceValue;
  final String currency;
  final String imageUrl;
  final String condition;
  final String itemWebUrl;

  final String appListingId;
  final String appTaxonomyBrandId;
  final String? appTaxonomyIpId;
  final String appCollectibleSeries;
  final String appCollectibleBrand;
  final String appReleaseDateIso;
  final String appImageSeed;
  final String appImageTintHex;
  final String appShelfAccentHex;
  final double appPriceChangePercent;
  final int appListingCount;
  final bool appIsTrending;
  final int appWatchingCount;
  final bool appHasSecretFigure;
  final bool appIsHardToFind;

  static EbayItemSummaryDto fromJson(Map<String, dynamic> json) {
    final price = json['price'] as Map<String, dynamic>? ?? const {};
    final image = json['image'] as Map<String, dynamic>? ?? const {};
    final app = json['app'] as Map<String, dynamic>? ?? const {};
    return EbayItemSummaryDto(
      itemId: json['itemId'] as String? ?? '',
      title: json['title'] as String? ?? '',
      priceValue: price['value'] as String? ?? '0',
      currency: price['currency'] as String? ?? 'USD',
      imageUrl: image['imageUrl'] as String? ?? '',
      condition: json['condition'] as String? ?? '',
      itemWebUrl: json['itemWebUrl'] as String? ?? '',
      appListingId: app['listingId'] as String? ?? json['itemId'] as String? ?? '',
      appTaxonomyBrandId: app['taxonomyBrandId'] as String? ?? '',
      appTaxonomyIpId: switch (app['taxonomyIpId']) {
        final String s => s,
        _ => null,
      },
      appCollectibleSeries: app['collectibleSeries'] as String? ?? '',
      appCollectibleBrand: app['collectibleBrand'] as String? ?? '',
      appReleaseDateIso: app['releaseDateIso'] as String? ?? '2026-01-01',
      appImageSeed: app['imageSeed'] as String? ?? '',
      appImageTintHex: app['imageTintHex'] as String? ?? 'ffffff',
      appShelfAccentHex: app['shelfAccentHex'] as String? ?? 'ffffffff',
      appPriceChangePercent: (app['priceChangePercent'] as num?)?.toDouble() ?? 0,
      appListingCount: (app['listingCount'] as num?)?.toInt() ?? 0,
      appIsTrending: app['isTrending'] as bool? ?? false,
      appWatchingCount: (app['watchingCount'] as num?)?.toInt() ?? 0,
      appHasSecretFigure: app['hasSecretFigure'] as bool? ?? false,
      appIsHardToFind: app['isHardToFind'] as bool? ?? false,
    );
  }
}
