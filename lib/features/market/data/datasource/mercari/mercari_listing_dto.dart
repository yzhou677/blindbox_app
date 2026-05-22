import 'package:flutter/foundation.dart';

/// Provider-shaped Mercari listing summary from the gateway (no catalog identity).
@immutable
class MercariListingDto {
  const MercariListingDto({
    required this.id,
    required this.title,
    required this.priceValue,
    required this.currency,
    required this.imageUrl,
    required this.listingUrl,
  });

  final String id;
  final String title;
  final String priceValue;
  final String currency;
  final String imageUrl;
  final String listingUrl;

  factory MercariListingDto.fromJson(Map<String, dynamic> json) {
    final price = json['price'] as Map<String, dynamic>? ?? const {};
    final image = json['image'] as Map<String, dynamic>? ?? const {};
    return MercariListingDto(
      id: json['id'] as String? ?? json['itemId'] as String? ?? '',
      title: json['title'] as String? ?? '',
      priceValue: price['value'] as String? ?? json['priceValue'] as String? ?? '0',
      currency: price['currency'] as String? ?? json['currency'] as String? ?? 'USD',
      imageUrl: image['imageUrl'] as String? ?? json['imageUrl'] as String? ?? '',
      listingUrl: json['listingUrl'] as String? ?? json['itemWebUrl'] as String? ?? '',
    );
  }
}
