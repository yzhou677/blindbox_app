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
    final parsed = tryParse(json);
    if (parsed == null) {
      throw FormatException('Invalid Mercari listing wire: $json');
    }
    return parsed;
  }

  /// Tolerant parse — skips malformed provider rows (schema drift).
  static MercariListingDto? tryParse(Map<String, dynamic> json) {
    final id = (json['id'] as String? ?? json['itemId'] as String? ?? '').trim();
    final title = (json['title'] as String? ?? '').trim();
    if (id.isEmpty || title.isEmpty) return null;

    final price = json['price'] as Map<String, dynamic>? ?? const {};
    final image = json['image'] as Map<String, dynamic>? ?? const {};
    return MercariListingDto(
      id: id,
      title: title,
      priceValue: _wirePriceValue(price, json),
      currency: price['currency'] as String? ?? json['currency'] as String? ?? 'USD',
      imageUrl: image['imageUrl'] as String? ?? json['imageUrl'] as String? ?? '',
      listingUrl: json['listingUrl'] as String? ?? json['itemWebUrl'] as String? ?? '',
    );
  }

  static String _wirePriceValue(
    Map<String, dynamic> price,
    Map<String, dynamic> json,
  ) {
    final raw = price['value'] ?? json['priceValue'];
    if (raw is String && raw.trim().isNotEmpty) return raw.trim();
    if (raw is num) return raw.toString();
    return '0';
  }
}
