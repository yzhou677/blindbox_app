import 'package:flutter/foundation.dart';

/// Single row for Add-to-Collection style UIs (local catalog, not marketplace).
@immutable
class CatalogSearchResult {
  const CatalogSearchResult({
    required this.figureId,
    required this.figureName,
    required this.seriesName,
    required this.brandId,
    required this.ipId,
    required this.imageKey,
    required this.isSecret,
  });

  final String figureId;
  final String figureName;
  final String seriesName;
  final String brandId;
  final String ipId;

  /// Opaque image identity; expand to a display path via `CatalogImageResolver.figureAsset`.
  final String imageKey;
  final bool isSecret;
}
