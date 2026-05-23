import 'package:blindbox_app/features/catalog/application/catalog_bundle_provider.dart';
import 'package:blindbox_app/features/collectible_relationship/application/collectible_affinity_resolver.dart';
import 'package:blindbox_app/features/collectible_relationship/application/collectible_relationship_index.dart';
import 'package:blindbox_app/features/collectible_relationship/application/shelf_harmony_interpreter.dart';
import 'package:blindbox_app/features/collectible_relationship/domain/collectible_relationship_hint.dart';
import 'package:blindbox_app/features/collectible_relationship/presentation/collectible_relationship_copy.dart';
import 'package:blindbox_app/features/collection/application/collection_notifier.dart';
import 'package:blindbox_app/features/collection/application/shelf_emotional_providers.dart';
import 'package:blindbox_app/features/collection/application/shelf_relationship_analyzer.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/market/application/collectible_market_providers.dart';
import 'package:blindbox_app/features/market/application/market_listings_providers.dart';
import 'package:blindbox_app/features/market/domain/collectible_market_snapshot.dart';
import 'package:blindbox_app/features/market/domain/market_identity_match.dart';
import 'package:blindbox_app/models/market_listing.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final collectibleRelationshipIndexProvider =
    Provider<CollectibleRelationshipIndex>((ref) {
  final snap = ref.watch(collectionNotifierProvider);
  final catalog = ref.watch(catalogBundleProvider).valueOrNull;
  return CollectibleRelationshipIndex.fromShelfAndCatalog(
    snap: snap,
    catalog: catalog,
  );
});

final shelfHarmonyLineProvider = Provider<String?>((ref) {
  final snap = ref.watch(collectionNotifierProvider);
  final profile = ref.watch(shelfEmotionalProfileProvider);
  final insights = ref.watch(shelfRelationshipInsightsProvider);
  return interpretShelfHarmonyLine(
    snap: snap,
    profile: profile,
    insights: insights,
  );
});

final shelfRelationshipWhisperProvider = Provider<String?>((ref) {
  final harmony = ref.watch(shelfHarmonyLineProvider);
  if (harmony != null && harmony.trim().isNotEmpty) return harmony;
  return null;
});

CollectibleRelationshipFocal _focalFromShelfSeries(ShelfSeries series) {
  return CollectibleRelationshipFocal(
    shelfSeriesId: series.id,
    catalogSeriesId: series.catalogTemplateId,
    taxonomyIpId: series.taxonomyIpId,
    taxonomyBrandId: series.taxonomyBrandId,
  );
}

CollectibleRelationshipFocal _focalFromMarketIdentity(
  CollectibleMarketSnapshot snapshot,
) {
  final id = snapshot.identity;
  return CollectibleRelationshipFocal(
    catalogSeriesId: id.matchedSeriesId,
    figureId: id.matchedFigureId,
    taxonomyIpId: id.matchedIpId,
    taxonomyBrandId: id.matchedBrandId,
  );
}

CollectibleRelationshipFocal _focalFromCatalogMatch(MarketIdentityMatch? match) {
  if (match == null) return const CollectibleRelationshipFocal();
  return CollectibleRelationshipFocal(
    catalogSeriesId: match.matchedSeriesId,
    figureId: match.matchedFigureId,
    taxonomyIpId: match.matchedIpId,
    taxonomyBrandId: match.matchedBrandId,
  );
}

String? _lineForFocal(
  CollectibleRelationshipFocal focal,
  CollectibleRelationshipIndex index,
) {
  final hint = resolveCollectibleRelationshipHint(
    focal: focal,
    index: index,
  );
  if (hint == null) return null;
  return CollectibleRelationshipCopy.lineForHint(hint: hint, index: index);
}

final relationshipHintForShelfSeriesProvider =
    Provider.family<String?, String>((ref, shelfSeriesId) {
  final snap = ref.watch(collectionNotifierProvider);
  ShelfSeries? series;
  for (final s in snap.shelfSeries) {
    if (s.id == shelfSeriesId) {
      series = s;
      break;
    }
  }
  if (series == null) return null;
  final index = ref.watch(collectibleRelationshipIndexProvider);
  return _lineForFocal(_focalFromShelfSeries(series), index);
});

final relationshipHintForCatalogSeriesProvider =
    Provider.family<String?, String>((ref, templateId) {
  final catalog = ref.watch(catalogBundleProvider).valueOrNull;
  if (catalog == null) return null;
  for (final s in catalog.series) {
    if (s.id != templateId) continue;
    final index = ref.watch(collectibleRelationshipIndexProvider);
    return _lineForFocal(
      CollectibleRelationshipFocal(
        catalogSeriesId: s.id,
        taxonomyIpId: s.ipId,
        taxonomyBrandId: s.brandId,
      ),
      index,
    );
  }
  return null;
});

final relationshipHintForMarketSnapshotProvider =
    Provider.family<String?, String>((ref, snapshotId) {
  final snapshots = ref.watch(collectibleMarketSnapshotsProvider);
  CollectibleMarketSnapshot? snapshot;
  for (final s in snapshots) {
    if (s.identity.snapshotId == snapshotId) {
      snapshot = s;
      break;
    }
  }
  if (snapshot == null) return null;
  final index = ref.watch(collectibleRelationshipIndexProvider);
  return _lineForFocal(_focalFromMarketIdentity(snapshot), index);
});

final relationshipHintForMarketListingProvider =
    Provider.family<String?, String>((ref, listingId) {
  final listings = ref.watch(marketBrowseListingsProvider);
  MarketListing? listing;
  for (final row in listings) {
    if (row.id == listingId) {
      listing = row;
      break;
    }
  }
  if (listing == null) return null;
  final index = ref.watch(collectibleRelationshipIndexProvider);
  return _lineForFocal(_focalFromCatalogMatch(listing.catalogMatch), index);
});
