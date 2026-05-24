import 'package:blindbox_app/models/market_listing.dart';

/// Shared listing-title quality signals — used by clustering and representative pick.
abstract final class MarketListingTitleSignals {
  static const noiseTerms = [
    'custom',
    'inspired',
    'bootleg',
    'fake',
    'replica',
    '3d print',
    'digital file',
    'wholesale lot',
  ];

  static const accessoryTerms = [
    'keychain',
    'key chain',
    'charm',
    'phone strap',
    'badge',
    'pin only',
    'pendant',
    'lanyard',
    'bag charm',
    'phone case',
  ];

  static const lotTerms = [
    'lot of',
    ' wholesale',
    'bundle',
    'set of',
    'full case',
    'display case',
    'case of',
  ];

  static bool isNoisy(String title) =>
      noiseTerms.any(title.toLowerCase().contains);

  static bool isAccessory(String title) =>
      accessoryTerms.any(title.toLowerCase().contains);

  static bool isLot(String title) {
    final lower = title.toLowerCase();
    return lotTerms.any(lower.contains) || RegExp(r'\blot\b').hasMatch(lower);
  }

  /// Higher = better thumbnail / representative candidate.
  static int presentationScore(MarketListing listing) {
    final title = listing.collectible.name.toLowerCase();
    var score = 0;

    if (listing.collectible.imageUrl.trim().isNotEmpty) score += 5;
    if (isNoisy(title)) score -= 10;
    if (isAccessory(title)) score -= 8;
    if (isLot(title)) score -= 7;
    if (RegExp(r'\bchoose\b|\bpick your\b|\brandom\b').hasMatch(title)) {
      score -= 3;
    }

    final words = title.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
    if (words <= 12) score += 2;
    if (words > 18) score -= 2;

    return score;
  }
}
