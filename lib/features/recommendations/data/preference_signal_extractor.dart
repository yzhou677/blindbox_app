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

  /// Catalog series with at least one owned figure — drives IP affinity scoring.
  final Set<String> ownedCatalogSeriesIds;
  final Set<String> wishlistCatalogSeriesIds;
  final Set<String> ownedIpIds;
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
    if (!_isEligibleCatalogSeries(series)) continue;

    final catalogId = series.catalogTemplateId!.trim();
    if (catalogId.isEmpty) continue;

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

bool _isEligibleCatalogSeries(ShelfSeries series) {
  final templateId = series.catalogTemplateId?.trim();
  if (templateId == null || templateId.isEmpty) return false;
  if (series.isCustomLocal) return false;
  if (series.isDropImport) return false;
  return true;
}

String _computeProfileHash(PreferenceSignals signals) {
  final buffer = StringBuffer();
  void writeSet(String key, Set<String> values) {
    buffer
      ..write(key)
      ..write(':');
    final sorted = values.toList()..sort();
    buffer
      ..write(sorted.join(','))
      ..write(';');
  }

  writeSet('trackedSeries', signals.trackedCatalogSeriesIds);
  writeSet('ownedSeries', signals.ownedCatalogSeriesIds);
  writeSet('wishlistSeries', signals.wishlistCatalogSeriesIds);
  writeSet('ownedIp', signals.ownedIpIds);
  writeSet('wishlistIp', signals.wishlistIpIds);

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
    'ownedCatalogSeriesIds': signals.ownedCatalogSeriesIds.toList()..sort(),
    'wishlistCatalogSeriesIds': signals.wishlistCatalogSeriesIds.toList()
      ..sort(),
    'ownedIpIds': signals.ownedIpIds.toList()..sort(),
    'wishlistIpIds': signals.wishlistIpIds.toList()..sort(),
    'profileHash': signals.profileHash,
  };
}
