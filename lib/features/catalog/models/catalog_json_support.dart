// Shared defensive reads for seed JSON / future cache payloads. No Flutter widgets.

import 'package:blindbox_app/features/catalog/catalog_image_resolver.dart';

List<String> catalogReadStringList(dynamic value) {
  if (value is! List) return const [];
  return value
      .map((e) {
        if (e is String) return e.trim();
        if (e != null) return e.toString().trim();
        return '';
      })
      .where((s) => s.isNotEmpty)
      .toList(growable: false);
}

String catalogReadString(Map<String, dynamic> json, String key, [String fallback = '']) {
  final v = json[key];
  if (v is String) return v;
  if (v != null) return v.toString();
  return fallback;
}

bool catalogReadBool(Map<String, dynamic> json, String key, {bool fallback = false}) {
  final v = json[key];
  if (v is bool) return v;
  return fallback;
}

int catalogReadInt(Map<String, dynamic> json, String key, {int fallback = 0}) {
  final v = json[key];
  if (v is int) return v;
  if (v is num) return v.toInt();
  return fallback;
}

Map<String, dynamic>? catalogReadMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return null;
}

/// Objects in a JSON array, skipping non-maps.
List<Map<String, dynamic>> catalogReadObjectList(dynamic value) {
  if (value is! List) return const [];
  final out = <Map<String, dynamic>>[];
  for (final e in value) {
    final m = catalogReadMap(e);
    if (m != null) out.add(m);
  }
  return out;
}

String? catalogReadIsoDateMaybe(Map<String, dynamic> json, String key) {
  final v = json[key];
  if (v == null) return null;
  if (v is String) {
    final t = v.trim();
    return t.isEmpty ? null : t;
  }
  return v.toString();
}

/// Prefer explicit `imageKey`, else stem from bundled `thumbnailAsset`, else canonical [fallbackId].
String catalogReadCatalogImageKey(
  Map<String, dynamic> json, {
  required String fallbackId,
  required String legacyThumbField,
}) {
  final k = catalogReadString(json, 'imageKey').trim();
  if (k.isNotEmpty) return k;
  final fromThumb = CatalogImageResolver.imageKeyFromLegacyThumbnailAsset(legacyThumbField);
  if (fromThumb.isNotEmpty) return fromThumb;
  final fb = fallbackId.trim();
  return fb;
}
