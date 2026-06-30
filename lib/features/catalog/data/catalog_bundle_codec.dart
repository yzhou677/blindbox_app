import 'dart:convert';

import 'package:blindbox_app/features/catalog/catalog_bundle.dart';
import 'package:blindbox_app/features/catalog/models/catalog_brand.dart';
import 'package:blindbox_app/features/catalog/models/catalog_figure.dart';
import 'package:blindbox_app/features/catalog/models/catalog_ip.dart';
import 'package:blindbox_app/features/catalog/models/catalog_json_support.dart';
import 'package:blindbox_app/features/catalog/models/catalog_series.dart';

/// JSON codec for persisting [CatalogSeedBundle] snapshots locally.
abstract final class CatalogBundleCodec {
  CatalogBundleCodec._();

  static const int schemaVersion = 1;

  static String encode(CatalogSeedBundle bundle, {DateTime? syncedAt}) {
    final at = (syncedAt ?? DateTime.now()).toUtc();
    return jsonEncode({
      'schemaVersion': schemaVersion,
      'syncedAt': at.toIso8601String(),
      'brands': [for (final b in bundle.brands) b.toJson()],
      'ips': [for (final ip in bundle.ips) ip.toJson()],
      'series': [for (final s in bundle.series) s.toJson()],
      'figures': [for (final f in bundle.figures) f.toJson()],
    });
  }

  /// Returns null when [raw] is empty, corrupt, or an unsupported schema version.
  static CatalogSeedBundle? tryDecode(String raw) {
    if (raw.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      final root = catalogReadMap(decoded);
      if (root == null) return null;
      final version = catalogReadInt(root, 'schemaVersion', fallback: -1);
      if (version != schemaVersion) return null;

      final brands = catalogReadObjectList(root['brands']);
      final ips = catalogReadObjectList(root['ips']);
      final series = catalogReadObjectList(root['series']);
      final figures = catalogReadObjectList(root['figures']);

      return CatalogSeedBundle(
        brands: [for (final m in brands) CatalogBrand.fromJson(m)],
        ips: [for (final m in ips) CatalogIp.fromJson(m)],
        series: [for (final m in series) CatalogSeries.fromJson(m)],
        figures: [for (final m in figures) CatalogFigure.fromJson(m)],
      );
    } on Object {
      return null;
    }
  }
}
