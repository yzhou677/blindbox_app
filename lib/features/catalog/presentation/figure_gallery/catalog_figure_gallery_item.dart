import 'package:flutter/material.dart';

/// One swipeable page in [CatalogFigureGallerySheet].
@immutable
class CatalogFigureGalleryItem {
  const CatalogFigureGalleryItem({
    required this.id,
    required this.name,
    this.catalogImageKey,
    this.imageUrl,
    this.localImageUri,
    this.rarityLabel,
    this.isSecret = false,
  });

  /// Stable identity for [ValueKey] / precache (figure id or slot id).
  final String id;
  final String name;

  /// Catalog Storage/bundled resolve key — preferred when present.
  final String? catalogImageKey;
  final String? imageUrl;
  final String? localImageUri;
  final String? rarityLabel;
  final bool isSecret;

  bool get hasCatalogKey {
    final k = catalogImageKey?.trim();
    return k != null && k.isNotEmpty;
  }
}
