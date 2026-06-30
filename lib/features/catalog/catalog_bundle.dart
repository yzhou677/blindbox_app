import 'dart:convert';

import 'package:blindbox_app/features/catalog/models/catalog_brand.dart';
import 'package:blindbox_app/features/catalog/models/catalog_figure.dart';
import 'package:blindbox_app/features/catalog/models/catalog_ip.dart';
import 'package:blindbox_app/features/catalog/models/catalog_json_support.dart';
import 'package:blindbox_app/features/catalog/models/catalog_series.dart';
import 'package:flutter/foundation.dart';

/// In-memory catalog metadata snapshot (Firestore, persistence, or runtime).
@immutable
class CatalogSeedBundle {
  const CatalogSeedBundle({
    required this.brands,
    required this.ips,
    required this.series,
    required this.figures,
  });

  final List<CatalogBrand> brands;
  final List<CatalogIp> ips;
  final List<CatalogSeries> series;
  final List<CatalogFigure> figures;
}

List<CatalogBrand> parseCatalogBrandsJson(String json) {
  final decoded = jsonDecode(json);
  return [for (final m in catalogReadObjectList(decoded)) CatalogBrand.fromJson(m)];
}

List<CatalogIp> parseCatalogIpsJson(String json) {
  final decoded = jsonDecode(json);
  return [for (final m in catalogReadObjectList(decoded)) CatalogIp.fromJson(m)];
}

List<CatalogSeries> parseCatalogSeriesJson(String json) {
  final decoded = jsonDecode(json);
  return [for (final m in catalogReadObjectList(decoded)) CatalogSeries.fromJson(m)];
}

List<CatalogFigure> parseCatalogFiguresJson(String json) {
  final decoded = jsonDecode(json);
  return [for (final m in catalogReadObjectList(decoded)) CatalogFigure.fromJson(m)];
}
