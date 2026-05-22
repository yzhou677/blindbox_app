import 'package:blindbox_app/features/market/domain/market_mood.dart';
import 'package:blindbox_app/features/market/domain/rarity_presence.dart';
import 'package:blindbox_app/models/market_listing.dart';

MarketMood resolveMarketMood({
  required int listingCount,
  required double avgPriceChangePercent,
  required bool anyHardToFind,
}) {
  if (listingCount >= 4) return MarketMood.active;
  if (listingCount == 1 && anyHardToFind) return MarketMood.scarce;
  if (listingCount <= 2 && avgPriceChangePercent.abs() < 1.5) {
    return MarketMood.calm;
  }
  if (listingCount >= 2 && avgPriceChangePercent.abs() >= 2.5) {
    return MarketMood.active;
  }
  return MarketMood.mixed;
}

RarityPresence resolveRarityPresence(List<MarketListing> rows) {
  var observed = false;
  var hinted = false;
  for (final row in rows) {
    if (row.hasSecretFigure) observed = true;
    final match = row.catalogMatch;
    if (match != null &&
        match.matchedFigureId != null &&
        match.matchedAliases.any((a) => a.toUpperCase().contains('SECRET'))) {
      hinted = true;
    }
  }
  if (observed) return RarityPresence.observed;
  if (hinted) return RarityPresence.hinted;
  return RarityPresence.none;
}
