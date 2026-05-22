import 'package:blindbox_app/features/market/data/market_browse_listings_session.dart';
import 'package:blindbox_app/features/market/data/market_catalog_identity_cache.dart';
import 'package:blindbox_app/features/market/domain/collectible_market_grouping_tier.dart';
import 'package:blindbox_app/features/market/domain/collectible_market_snapshot.dart';
import 'package:blindbox_app/models/market_listing.dart';
import 'package:flutter/foundation.dart';

/// Resolved presentation labels for a snapshot (not stored on domain types).
@immutable
class CollectibleMarketDisplay {
  const CollectibleMarketDisplay({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;
}

CollectibleMarketDisplay resolveCollectibleMarketDisplay(
  CollectibleMarketSnapshot snapshot,
) {
  final rep = MarketBrowseListingsSession.instance.findById(
    snapshot.representativeListingId,
  );
  final index = MarketCatalogIdentityCache.current;

  final figureId = snapshot.identity.matchedFigureId;
  if (figureId != null && index != null) {
    final figure = index.figureById(figureId);
    if (figure != null) {
      final seriesName = index.seriesById(figure.seriesId)?.displayName;
      return CollectibleMarketDisplay(
        title: figure.displayName,
        subtitle: seriesName ?? rep?.collectible.series ?? '',
      );
    }
  }

  final seriesId = snapshot.identity.matchedSeriesId;
  if (snapshot.identity.groupingTier == CollectibleMarketGroupingTier.series &&
      seriesId != null &&
      index != null) {
    final series = index.seriesById(seriesId);
    if (series != null) {
      return CollectibleMarketDisplay(
        title: series.displayName,
        subtitle: rep?.collectible.brand ?? '',
      );
    }
  }

  return CollectibleMarketDisplay(
    title: rep?.collectible.name ?? 'Collectible',
    subtitle: rep?.collectible.series ?? '',
  );
}

MarketListing? representativeListing(CollectibleMarketSnapshot snapshot) {
  return MarketBrowseListingsSession.instance.findById(
    snapshot.representativeListingId,
  );
}

List<MarketListing> listingsForSnapshot(CollectibleMarketSnapshot snapshot) {
  final out = <MarketListing>[];
  for (final id in snapshot.listingIds) {
    final row = MarketBrowseListingsSession.instance.findById(id);
    if (row != null) out.add(row);
  }
  return out;
}
