import 'package:flutter/foundation.dart';

import 'catalog_json_support.dart';

@immutable
class CatalogBrand {
  const CatalogBrand({
    required this.id,
    required this.displayName,
    this.aliases = const [],
  });

  final String id;
  final String displayName;
  final List<String> aliases;

  factory CatalogBrand.fromJson(Map<String, dynamic> json) {
    return CatalogBrand(
      id: catalogReadString(json, 'id'),
      displayName: catalogReadString(json, 'displayName'),
      aliases: catalogReadStringList(json['aliases']),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'displayName': displayName,
        if (aliases.isNotEmpty) 'aliases': aliases,
      };
}
