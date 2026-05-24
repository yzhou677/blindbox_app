import 'package:flutter/foundation.dart';

/// Provider item detail wire from the market gateway (`GET /v1/item`).
@immutable
class GatewayItemDetailDto {
  const GatewayItemDetailDto({
    required this.itemId,
    required this.title,
    required this.priceValue,
    required this.currency,
    required this.imageUrl,
    required this.listingUrl,
    this.condition,
    this.shortDescription,
    this.sellerUsername,
    this.sellerFeedbackPercentage,
    this.shippingSummary,
  });

  final String itemId;
  final String title;
  final String priceValue;
  final String currency;
  final String imageUrl;
  final String listingUrl;
  final String? condition;
  final String? shortDescription;
  final String? sellerUsername;
  final String? sellerFeedbackPercentage;
  final String? shippingSummary;

  static GatewayItemDetailDto? tryParse(Map<String, dynamic> json) {
    final item = json['item'] as Map<String, dynamic>?;
    if (item == null) return null;
    return _parseItem(item);
  }

  static GatewayItemDetailDto? _parseItem(Map<String, dynamic> json) {
    final itemId = (json['itemId'] as String? ?? '').trim();
    final title = (json['title'] as String? ?? '').trim();
    if (itemId.isEmpty || title.isEmpty) return null;

    final price = json['price'] as Map<String, dynamic>? ?? const {};
    final seller = json['seller'] as Map<String, dynamic>?;
    final shipping = json['shipping'] as Map<String, dynamic>?;

    return GatewayItemDetailDto(
      itemId: itemId,
      title: title,
      priceValue: _wirePriceValue(price),
      currency: price['currency'] as String? ?? 'USD',
      imageUrl: json['imageUrl'] as String? ?? '',
      listingUrl: json['listingUrl'] as String? ?? '',
      condition: (json['condition'] as String?)?.trim(),
      shortDescription: (json['shortDescription'] as String?)?.trim(),
      sellerUsername: (seller?['username'] as String?)?.trim(),
      sellerFeedbackPercentage:
          (seller?['feedbackPercentage'] as String?)?.trim(),
      shippingSummary: (shipping?['summary'] as String?)?.trim(),
    );
  }

  static String _wirePriceValue(Map<String, dynamic> price) {
    final raw = price['value'];
    if (raw is String && raw.trim().isNotEmpty) return raw.trim();
    if (raw is num) return raw.toString();
    return '0';
  }
}
