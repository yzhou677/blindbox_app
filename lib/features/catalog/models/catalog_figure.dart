import 'package:flutter/foundation.dart';

import 'package:blindbox_app/features/catalog/models/catalog_json_support.dart';

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
    this.aliases = const [],
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

  /// Alternate marketplace / collector names for this figure (e.g. `Lucky` for `Luck`).
  ///
  /// Canonical identity remains [displayName]. Aliases are used by catalog search and
  /// the market-intel pipeline matcher — not a second metadata alias store.
  final List<String> aliases;

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
      aliases: catalogReadStringList(json['aliases']),
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
        if (aliases.isNotEmpty) 'aliases': aliases,
      };
}
