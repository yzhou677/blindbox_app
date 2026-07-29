import 'package:flutter/foundation.dart';

import 'package:blindbox_app/features/catalog/models/catalog_json_support.dart';

@immutable
class CatalogSeries {
  const CatalogSeries({
    required this.id,
    required this.brandId,
    required this.ipId,
    required this.displayName,
    required this.releaseDate,
    required this.isBlindBox,
    required this.imageKey,
    this.aliases = const [],
  });

  final String id;
  final String brandId;
  final String ipId;
  final String displayName;

  /// Official **U.S.** release date from the U.S. storefront / website.
  ///
  /// Stored as an ISO date-only string (`YYYY-MM-DD`), or **null** when unknown
  /// / cleared upstream. Serialized key remains `releaseDate` (no migration).
  /// This is not a worldwide, China, Japan, or EU launch date — regional
  /// calendars may differ. Do not invent dates from names or market listings.
  final String? releaseDate;
  final bool isBlindBox;

  /// Opaque illustration id (typically matches [id]); resolves via [CatalogImageResolver].
  final String imageKey;

  /// Search aliases from Firestore (e.g. shortened series titles).
  final List<String> aliases;

  factory CatalogSeries.fromJson(Map<String, dynamic> json) {
    final id = catalogReadString(json, 'id');
    return CatalogSeries(
      id: id,
      brandId: catalogReadString(json, 'brandId'),
      ipId: catalogReadString(json, 'ipId'),
      displayName: catalogReadString(json, 'displayName'),
      releaseDate: catalogReadIsoDateMaybe(json, 'releaseDate'),
      isBlindBox: catalogReadBool(json, 'isBlindBox'),
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
    'brandId': brandId,
    'ipId': ipId,
    'displayName': displayName,
    if (releaseDate != null) 'releaseDate': releaseDate,
    'isBlindBox': isBlindBox,
    'imageKey': imageKey,
    if (aliases.isNotEmpty) 'aliases': aliases,
  };
}
