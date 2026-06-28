import 'package:flutter/material.dart';

/// One swipeable page in [CatalogFigureGallerySheet].
///
/// UI renders via [localImageUri], optional [seriesCoverImageUri] fallback,
/// then [catalogImageKey] ([CatalogImageFromKey]) — matching [ShelfFigureThumb].
@immutable
class CatalogFigureGalleryItem {
  const CatalogFigureGalleryItem({
    required this.id,
    required this.name,
    this.catalogImageKey,
    this.localImageUri,
    this.seriesCoverImageUri,
    this.rarityLabel,
    this.oddsLabel,
    this.isSecret = false,
  });

  /// Stable identity for [ValueKey] / precache (figure id or slot id).
  final String id;
  final String name;

  /// Canonical catalog [imageKey] for [CatalogImageResolver].
  final String? catalogImageKey;
  final String? localImageUri;

  /// User series cover when the figure has no dedicated photo (shelf parity).
  final String? seriesCoverImageUri;
  /// Descriptive rarity (e.g. Rare, Super Rare Secret) — not pull odds.
  final String? rarityLabel;

  /// Pull odds (e.g. `1:72`) when known separately from [rarityLabel].
  final String? oddsLabel;
  final bool isSecret;

  bool get hasCatalogKey {
    final k = catalogImageKey?.trim();
    return k != null && k.isNotEmpty;
  }
}
