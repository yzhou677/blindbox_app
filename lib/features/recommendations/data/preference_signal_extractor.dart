import 'dart:convert';

import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

/// Named signal surface distilled from the local collection.
///
/// Not a collection mirror — future signals (viewed, liked, etc.) can be added
/// as new optional fields without changing the upload contract.
@immutable
class PreferenceSignals {
  const PreferenceSignals({
    required this.trackedCatalogSeriesIds,
    required this.ownedCatalogSeriesIds,
    required this.wishlistCatalogSeriesIds,
    required this.ownedIpIds,
    required this.wishlistIpIds,
    required this.trackedCatalogSeriesCount,
    required this.ownedCatalogSeriesCount,
    required this.wishlistCatalogSeriesCount,
    required this.profileHash,
  });

  /// Catalog series present on the user's shelf (My Collection), regardless of
  /// figure ownership — drives recommendation exclusion.
  final Set<String> trackedCatalogSeriesIds;

  /// Catalog series with at least one owned figure — used for IP affinity scoring
  /// at compute time only; does not affect [profileHash] or refresh triggers.
  final Set<String> ownedCatalogSeriesIds;
  /// Wishlist progress inside tracked series — collection/Market only; not used
  /// by the recommendation pipeline.
  final Set<String> wishlistCatalogSeriesIds;
  /// Taxonomy IPs with owned figures — scoring snapshot at last tracked refresh.
  final Set<String> ownedIpIds;
  /// Taxonomy IPs with wishlist figures — not used by recommendations.
  final Set<String> wishlistIpIds;
  final int trackedCatalogSeriesCount;
  final int ownedCatalogSeriesCount;
  final int wishlistCatalogSeriesCount;
  final String profileHash;
}

PreferenceSignals extractSignals(CollectionSnapshot snap) {
  final trackedCatalogSeriesIds = <String>{};
  final ownedCatalogSeriesIds = <String>{};
  final wishlistCatalogSeriesIds = <String>{};
  final ownedIpIds = <String>{};
  final wishlistIpIds = <String>{};

  for (final series in snap.shelfSeries) {
    final catalogId = recommendationCatalogSeriesId(series);
    if (catalogId == null) continue;

    trackedCatalogSeriesIds.add(catalogId);

    final progress = progressForSeries(series, snap.figureStates);
    if (progress.owned > 0) {
      ownedCatalogSeriesIds.add(catalogId);
      final ipId = series.taxonomyIpId?.trim();
      if (ipId != null && ipId.isNotEmpty) {
        ownedIpIds.add(ipId);
      }
    } else if (progress.wishlist > 0) {
      wishlistCatalogSeriesIds.add(catalogId);
      final ipId = series.taxonomyIpId?.trim();
      if (ipId != null && ipId.isNotEmpty) {
        wishlistIpIds.add(ipId);
      }
    }
  }

  final signals = PreferenceSignals(
    trackedCatalogSeriesIds: trackedCatalogSeriesIds,
    ownedCatalogSeriesIds: ownedCatalogSeriesIds,
    wishlistCatalogSeriesIds: wishlistCatalogSeriesIds,
    ownedIpIds: ownedIpIds,
    wishlistIpIds: wishlistIpIds,
    trackedCatalogSeriesCount: trackedCatalogSeriesIds.length,
    ownedCatalogSeriesCount: ownedCatalogSeriesIds.length,
    wishlistCatalogSeriesCount: wishlistCatalogSeriesIds.length,
    profileHash: '',
  );

  return PreferenceSignals(
    trackedCatalogSeriesIds: trackedCatalogSeriesIds,
    ownedCatalogSeriesIds: ownedCatalogSeriesIds,
    wishlistCatalogSeriesIds: wishlistCatalogSeriesIds,
    ownedIpIds: ownedIpIds,
    wishlistIpIds: wishlistIpIds,
    trackedCatalogSeriesCount: trackedCatalogSeriesIds.length,
    ownedCatalogSeriesCount: ownedCatalogSeriesIds.length,
    wishlistCatalogSeriesCount: wishlistCatalogSeriesIds.length,
    profileHash: _computeProfileHash(signals),
  );
}

String _computeProfileHash(PreferenceSignals signals) {
  final sorted = signals.trackedCatalogSeriesIds.toList()..sort();
  final buffer = StringBuffer()
    ..write('trackedSeries:')
    ..write(sorted.join(','));
  final digest = sha256.convert(utf8.encode(buffer.toString()));
  return digest.toString();
}

Map<String, dynamic> preferenceSignalsToProfileJson({
  required String installId,
  required PreferenceSignals signals,
}) {
  return {
    'installId': installId,
    'trackedCatalogSeriesIds': signals.trackedCatalogSeriesIds.toList()..sort(),
    // Owned IP snapshot for cloud scoring when tracked taste changes — not part
    // of profileHash, so figure progress alone does not reshuffle For You.
    'ownedIpIds': signals.ownedIpIds.toList()..sort(),
    'profileHash': signals.profileHash,
  };
}
