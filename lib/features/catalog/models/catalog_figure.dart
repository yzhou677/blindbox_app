import 'package:flutter/foundation.dart';

import 'catalog_json_support.dart';

@immutable
class CatalogFigure {
  const CatalogFigure({
    required this.id,
    required this.seriesId,
    required this.brandId,
    required this.ipId,
    required this.displayName,
    required this.isSecret,
    this.rarityLabel,
    required this.sortOrder,
    required this.thumbnailAsset,
  });

  final String id;
  final String seriesId;
  final String brandId;
  final String ipId;
  final String displayName;
  final bool isSecret;
  final String? rarityLabel;
  final int sortOrder;
  final String thumbnailAsset;

  factory CatalogFigure.fromJson(Map<String, dynamic> json) {
    final rarityStr = catalogReadString(json, 'rarityLabel');
    return CatalogFigure(
      id: catalogReadString(json, 'id'),
      seriesId: catalogReadString(json, 'seriesId'),
      brandId: catalogReadString(json, 'brandId'),
      ipId: catalogReadString(json, 'ipId'),
      displayName: catalogReadString(json, 'displayName'),
      isSecret: catalogReadBool(json, 'isSecret'),
      rarityLabel: rarityStr.isEmpty ? null : rarityStr,
      sortOrder: catalogReadInt(json, 'sortOrder'),
      thumbnailAsset: catalogReadString(json, 'thumbnailAsset').trim(),
    );
  }
}
