import 'package:blindbox_app/models/collectible.dart';
import 'package:flutter/foundation.dart';

/// One slot in a blind-box [SeriesRelease] lineup (catalog-facing, not shelf state).
@immutable
class ReleaseLineupSlot {
  const ReleaseLineupSlot({
    required this.slotId,
    required this.name,
    this.imageUrl,
    required this.isSecret,
  });

  final String slotId;
  final String name;
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
    required this.heroCollectible,
    required this.lineup,
  });

  final String dropId;
  final String seriesName;
  final String brand;
  final String? ipLine;
  final DateTime releaseDate;
  final Collectible heroCollectible;
  final List<ReleaseLineupSlot> lineup;

  bool get hasSecretInLineup => lineup.any((s) => s.isSecret);
}
