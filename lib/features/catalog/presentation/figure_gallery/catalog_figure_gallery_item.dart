import 'package:flutter/material.dart';

/// One swipeable page in [CatalogFigureGallerySheet].
///
/// UI renders via [catalogImageKey] ([CatalogImageFromKey]) or [localImageUri] only.
@immutable
class CatalogFigureGalleryItem {
  const CatalogFigureGalleryItem({
    required this.id,
    required this.name,
    this.catalogImageKey,
    this.localImageUri,
    this.rarityLabel,
    this.isSecret = false,
  });

  /// Stable identity for [ValueKey] / precache (figure id or slot id).
  final String id;
  final String name;

  /// Canonical catalog [imageKey] for [CatalogImageResolver].
  final String? catalogImageKey;
  final String? localImageUri;
  final String? rarityLabel;
  final bool isSecret;

  bool get hasCatalogKey {
    final k = catalogImageKey?.trim();
    return k != null && k.isNotEmpty;
  }
}
