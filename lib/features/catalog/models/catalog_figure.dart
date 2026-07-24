import 'package:flutter/foundation.dart';

import 'package:blindbox_app/features/catalog/models/catalog_json_support.dart';

/// Recognition-only supplemental catalog image. Not shown in the catalog UI.
@immutable
class CatalogAlternativeImage {
  const CatalogAlternativeImage({
    required this.imageKey,
    required this.variant,
  });

  final String imageKey;
  final String variant;

  factory CatalogAlternativeImage.fromJson(Map<String, dynamic> json) {
    return CatalogAlternativeImage(
      imageKey: catalogReadString(json, 'imageKey').trim(),
      variant: catalogReadString(json, 'variant').trim(),
    );
  }

  Map<String, dynamic> toJson() => {
        'imageKey': imageKey,
        'variant': variant,
      };
}

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
    required this.imageKey,
    this.alternativeImages = const [],
  });

  final String id;
  final String seriesId;
  final String brandId;
  final String ipId;
  final String displayName;
  final bool isSecret;
  final String? rarityLabel;
  final int sortOrder;

  /// Opaque illustration id (matches canonical figure [id]); resolves via [CatalogImageResolver].
  final String imageKey;

  /// Optional recognition-only supplemental images. Never used by catalog UI.
  final List<CatalogAlternativeImage> alternativeImages;

  factory CatalogFigure.fromJson(Map<String, dynamic> json) {
    final rarityStr = catalogReadString(json, 'rarityLabel');
    final id = catalogReadString(json, 'id');
    return CatalogFigure(
      id: id,
      seriesId: catalogReadString(json, 'seriesId'),
      brandId: catalogReadString(json, 'brandId'),
      ipId: catalogReadString(json, 'ipId'),
      displayName: catalogReadString(json, 'displayName'),
      isSecret: catalogReadBool(json, 'isSecret'),
      rarityLabel: rarityStr.isEmpty ? null : rarityStr,
      sortOrder: catalogReadInt(json, 'sortOrder'),
      imageKey: catalogReadCatalogImageKey(
        json,
        fallbackId: id,
        legacyThumbField: catalogReadString(json, 'thumbnailAsset'),
      ),
      alternativeImages: _readAlternativeImages(json['alternativeImages']),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'seriesId': seriesId,
        'brandId': brandId,
        'ipId': ipId,
        'displayName': displayName,
        'isSecret': isSecret,
        if (rarityLabel != null) 'rarityLabel': rarityLabel,
        'sortOrder': sortOrder,
        'imageKey': imageKey,
        if (alternativeImages.isNotEmpty)
          'alternativeImages': [
            for (final alt in alternativeImages) alt.toJson(),
          ],
      };
}

List<CatalogAlternativeImage> _readAlternativeImages(dynamic raw) {
  final rows = catalogReadObjectList(raw);
  if (rows.isEmpty) return const [];
  final out = <CatalogAlternativeImage>[];
  final seen = <String>{};
  for (final row in rows) {
    final alt = CatalogAlternativeImage.fromJson(row);
    if (alt.imageKey.isEmpty || alt.variant.isEmpty) continue;
    if (!seen.add(alt.imageKey)) continue;
    out.add(alt);
  }
  return List<CatalogAlternativeImage>.unmodifiable(out);
}
