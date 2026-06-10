import 'package:flutter/foundation.dart';

import 'catalog_json_support.dart';

@immutable
class CatalogIp {
  const CatalogIp({
    required this.id,
    required this.brandId,
    required this.displayName,
    this.aliases = const [],
  });

  final String id;
  final String brandId;
  final String displayName;
  final List<String> aliases;

  factory CatalogIp.fromJson(Map<String, dynamic> json) {
    return CatalogIp(
      id: catalogReadString(json, 'id'),
      brandId: catalogReadString(json, 'brandId'),
      displayName: catalogReadString(json, 'displayName'),
      aliases: catalogReadStringList(json['aliases']),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'brandId': brandId,
        'displayName': displayName,
        if (aliases.isNotEmpty) 'aliases': aliases,
      };
}
