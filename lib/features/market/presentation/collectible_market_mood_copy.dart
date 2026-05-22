import 'package:blindbox_app/features/market/domain/collectible_market_snapshot.dart';
import 'package:blindbox_app/features/market/domain/market_mood.dart';
import 'package:blindbox_app/features/market/domain/rarity_presence.dart';

/// Editorial mood lines — calm companion tone, not trader copy.
abstract final class CollectibleMarketMoodCopy {
  static String subtitle(CollectibleMarketSnapshot snapshot) {
    if (snapshot.rarityPresence == RarityPresence.observed) {
      return 'A rare sighting in the market';
    }
    if (snapshot.rarityPresence == RarityPresence.hinted) {
      return 'Something special may be hiding here';
    }
    return switch (snapshot.marketMood) {
      MarketMood.calm => 'A calm market week',
      MarketMood.active => 'Showing up in a few places lately',
      MarketMood.scarce => 'Rarely seen lately',
      MarketMood.mixed => 'Quiet but varied sightings',
    };
  }

  static String sightingsLabel(int count) {
    if (count <= 1) return '1 sighting';
    return '$count sightings';
  }
}
