import 'package:blindbox_app/models/collectible.dart';
import 'package:flutter/foundation.dart';

/// One slot in a blind-box [SeriesRelease] lineup (catalog-facing, not shelf state).
@immutable
class ReleaseLineupSlot {
  const ReleaseLineupSlot({
    required this.slotId,
    required this.name,
    required this.imageKey,
    this.imageUrl,
    required this.isSecret,
  });

  final String slotId;
  final String name;

  /// Canonical catalog figure [imageKey] (`catalog/figures/<imageKey>.*`).
  final String imageKey;

  /// Legacy/mock preset URL — UI ignores; use [imageKey] with [CatalogImageFromKey].
  final String? imageUrl;
  final bool isSecret;
}

/// A Home “latest drop” as a **series launch**: hero art + full lineup for browsing.
///
/// [dropId] matches route `/home/detail/:id` and `Collectible.id` on [heroCollectible].
@immutable
class SeriesRelease {
  const SeriesRelease({
    required this.dropId,
    required this.seriesName,
    required this.brand,
    this.ipLine,
    required this.releaseDate,
    required this.seriesImageKey,
    required this.heroCollectible,
    required this.lineup,
    this.taxonomyBrandId,
    this.taxonomyIpId,
  });

  final String dropId;
  final String seriesName;

  /// Canonical catalog series cover [imageKey] (`catalog/series/<imageKey>.*`).
  final String seriesImageKey;
  final String brand;
  final String? ipLine;
  final DateTime releaseDate;
  final Collectible heroCollectible;
  final List<ReleaseLineupSlot> lineup;

  /// When set, copied onto shelf rows on import (aligned with [MarketListing.taxonomyBrandId]).
  final String? taxonomyBrandId;

  /// When set, copied onto shelf rows on import (aligned with [MarketListing.taxonomyIpId]).
  final String? taxonomyIpId;

  bool get hasSecretInLineup => lineup.any((s) => s.isSecret);

  /// Home feed card subtitle (`brand · IP`), not the hero figure name.
  String get feedCardMetaLine {
    final line = ipLine?.trim();
    if (line != null && line.isNotEmpty) return line;
    final brandLabel = brand.trim();
    if (brandLabel.isNotEmpty) return brandLabel;
    return seriesName;
  }
}
