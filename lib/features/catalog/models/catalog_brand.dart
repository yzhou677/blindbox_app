import 'package:flutter/foundation.dart';

import 'catalog_json_support.dart';

@immutable
class CatalogBrand {
  const CatalogBrand({
    required this.id,
    required this.displayName,
    this.aliases = const [],
    this.updatedAt,
  });

  final String id;
  final String displayName;
  final List<String> aliases;

  /// Firestore sync watermark (optional until backfill / older caches).
  final DateTime? updatedAt;

  factory CatalogBrand.fromJson(Map<String, dynamic> json) {
    return CatalogBrand(
      id: catalogReadString(json, 'id'),
      displayName: catalogReadString(json, 'displayName'),
      aliases: catalogReadStringList(json['aliases']),
      updatedAt: catalogReadDateTimeMaybe(json, 'updatedAt'),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'displayName': displayName,
    if (aliases.isNotEmpty) 'aliases': aliases,
    if (updatedAt != null) 'updatedAt': updatedAt!.toUtc().toIso8601String(),
  };
}
