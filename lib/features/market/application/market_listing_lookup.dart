import 'package:blindbox_app/features/market/application/market_chasers_controller.dart';
import 'package:blindbox_app/features/market/application/market_listings_providers.dart';
import 'package:blindbox_app/features/market/data/cache/market_chasers_cache.dart';
import 'package:blindbox_app/features/market/domain/chasers_heat_entry.dart';
import 'package:blindbox_app/models/market_listing.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final marketListingByIdProvider = Provider.family<MarketListing?, String>(
  (ref, listingId) => findMarketListingById(ref, listingId),
);

final chaserEntryByListingIdProvider = Provider.family<ChasersHeatEntry?, String>(
  (ref, listingId) => findChaserEntryByListingId(ref, listingId),
);

ChasersHeatEntry? findChaserEntryByListingId(Ref ref, String listingId) {
  for (final entry in ref.watch(marketChasersControllerProvider).entries) {
    if (entry.representativeListing.id == listingId) return entry;
  }
  return _findChaserEntryInCache(listingId);
}

MarketListing? findMarketListingById(Ref ref, String listingId) {
  for (final listing in ref.watch(marketBrowseListingsProvider)) {
    if (listing.id == listingId) return listing;
  }
  return findChaserEntryByListingId(ref, listingId)?.representativeListing;
}

ChasersHeatEntry? _findChaserEntryInCache(String listingId) {
  final batch = MarketChasersCache.instance.readMemory(allowExpired: true);
  if (batch == null) return null;
  for (final entry in batch.entries) {
    if (entry.representativeListing.id == listingId) return entry;
  }
  return null;
}
