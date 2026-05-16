import 'package:flutter/foundation.dart';

import 'catalog_json_support.dart';

@immutable
class CatalogSeries {
  const CatalogSeries({
    required this.id,
    required this.brandId,
    required this.ipId,
    required this.displayName,
    required this.releaseDate,
    required this.isBlindBox,
    required this.thumbnailAsset,
  });

  final String id;
  final String brandId;
  final String ipId;
  final String displayName;

  /// ISO-style date string from seed (e.g. `2023-10-27`).
  final String releaseDate;
  final bool isBlindBox;

  /// App asset path (e.g. `assets/catalog/series/...`).
  final String thumbnailAsset;

  factory CatalogSeries.fromJson(Map<String, dynamic> json) {
    return CatalogSeries(
      id: catalogReadString(json, 'id'),
      brandId: catalogReadString(json, 'brandId'),
      ipId: catalogReadString(json, 'ipId'),
      displayName: catalogReadString(json, 'displayName'),
      releaseDate: catalogReadString(json, 'releaseDate'),
      isBlindBox: catalogReadBool(json, 'isBlindBox'),
      thumbnailAsset: catalogReadString(json, 'thumbnailAsset'),
    );
  }
}
