import 'package:blindbox_app/features/market/domain/collectible_market_snapshot.dart';
import 'package:blindbox_app/features/market/domain/market_mood.dart';
import 'package:blindbox_app/features/market/domain/rarity_presence.dart';
import 'package:blindbox_app/features/market/utils/market_format.dart';
import 'package:blindbox_app/models/market_listing.dart';

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
      MarketMood.mixed => 'Quiet but varied activity',
    };
  }

  /// Soft observation line — no counts.
  static String observedInMarketLine() => 'Observed in market';

  static String recentlyActiveLine() => 'Recently active';

  static String activeListingLine() => 'Active listing';

  /// Chasers rail subtitle — IP context only, no numeric heat.
  static String? chaserRailSubtitle({required String ipLabel}) {
    final ip = ipLabel.trim();
    if (ip.isEmpty) return recentlyActiveLine();
    return ip;
  }

  /// Single-listing detail — calm market context without trader copy.
  static String listingDetailLine(MarketListing listing) {
    if (listing.hasSecretFigure) return 'A rare sighting in the market';
    if (listing.isHardToFind) return 'Rarely seen lately';
    if (listing.isTrending) return 'Showing up in a few places lately';
    return observedInMarketLine();
  }

  static String snapshotPriceLabel(CollectibleMarketSnapshot snapshot) {
    final range = snapshot.observedPriceRange;
    if (snapshot.listingCount > 1 && !range.isSinglePrice) {
      return '${formatMarketUsd(range.minUsd)}–${formatMarketUsd(range.maxUsd)}';
    }
    return formatMarketUsd(range.minUsd);
  }
}
