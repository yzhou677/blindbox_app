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
    required this.thumbnailAsset,
    required this.isSecret,
  });

  final String figureId;
  final String figureName;
  final String seriesName;
  final String brandId;
  final String ipId;
  final String thumbnailAsset;
  final bool isSecret;
}
