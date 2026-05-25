import 'package:flutter/foundation.dart';

/// Enriched listing facts from gateway item detail — separate from browse row state.
@immutable
class MarketListingDetail {
  const MarketListingDetail({
    required this.itemId,
    required this.title,
    required this.imageUrl,
    required this.listingUrl,
    this.condition,
    this.quantityAvailable,
    this.availabilityStatus,
    this.shortDescription,
    this.sellerLine,
    this.shippingSummary,
  });

  final String itemId;
  final String title;
  final String imageUrl;
  final String listingUrl;
  final String? condition;
  final int? quantityAvailable;
  final String? availabilityStatus;
  final String? shortDescription;
  final String? sellerLine;
  final String? shippingSummary;
}
