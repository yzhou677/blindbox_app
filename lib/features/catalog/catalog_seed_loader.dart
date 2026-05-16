import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'package:blindbox_app/features/catalog/models/catalog_brand.dart';
import 'package:blindbox_app/features/catalog/models/catalog_figure.dart';
import 'package:blindbox_app/features/catalog/models/catalog_ip.dart';
import 'package:blindbox_app/features/catalog/models/catalog_json_support.dart';
import 'package:blindbox_app/features/catalog/models/catalog_series.dart';

/// In-memory snapshot of bundled JSON under `tools/seed/`.
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

/// Parse helpers — pure Dart, easy to unit-test without asset I/O.

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

/// Loads all seed catalogs from the app bundle (`pubspec` must list `tools/seed/`).
Future<CatalogSeedBundle> loadCatalogSeedBundle() async {
  final brandsRaw = await rootBundle.loadString('tools/seed/brands.json');
  final ipsRaw = await rootBundle.loadString('tools/seed/ips.json');
  final seriesRaw = await rootBundle.loadString('tools/seed/series.json');
  final figuresRaw = await rootBundle.loadString('tools/seed/figures.json');
  return CatalogSeedBundle(
    brands: parseCatalogBrandsJson(brandsRaw),
    ips: parseCatalogIpsJson(ipsRaw),
    series: parseCatalogSeriesJson(seriesRaw),
    figures: parseCatalogFiguresJson(figuresRaw),
  );
}
