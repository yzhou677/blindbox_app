import 'package:blindbox_app/features/catalog/catalog_image_resolver.dart';
import 'package:blindbox_app/features/catalog/catalog_seed_loader.dart';
import 'package:blindbox_app/features/catalog/models/catalog_brand.dart';
import 'package:blindbox_app/features/catalog/models/catalog_figure.dart';
import 'package:blindbox_app/features/catalog/models/catalog_ip.dart';
import 'package:blindbox_app/features/catalog/models/catalog_series.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart' as domain;
import 'package:flutter/material.dart';

/// Builds a collection add-sheet / clone template from curated seed JSON.
///
/// Returns null if [seriesId] is unknown or has no figures in the bundle.
Future<domain.CatalogSeries?> catalogTemplateFromSeedSeries(
  CatalogSeedBundle bundle,
  String seriesId,
) async {
  CatalogSeries? series;
  for (final s in bundle.series) {
    if (s.id == seriesId) {
      series = s;
      break;
    }
  }
  if (series == null) return null;

  CatalogBrand? brand;
  for (final b in bundle.brands) {
    if (b.id == series.brandId) {
      brand = b;
      break;
    }
  }
  CatalogIp? ip;
  for (final i in bundle.ips) {
    if (i.id == series.ipId) {
      ip = i;
      break;
    }
  }

  final brandLine = brand?.displayName ?? series.brandId;
  final ipLine = ip?.displayName ?? series.ipId;

  final figs = <CatalogFigure>[];
  for (final f in bundle.figures) {
    if (f.seriesId == seriesId) figs.add(f);
  }
  if (figs.isEmpty) return null;
  figs.sort((a, b) {
    final o = a.sortOrder.compareTo(b.sortOrder);
    if (o != 0) return o;
    return a.id.compareTo(b.id);
  });

  const accents = <Color>[
    Color(0xFFE8E4F8),
    Color(0xFFF2E8DC),
    Color(0xFFE4F2EA),
    Color(0xFFE4EDFA),
    Color(0xFFFCE4EC),
    Color(0xFFEAF6FB),
  ];
  final accent = accents[seriesId.hashCode.abs() % accents.length];

  final templateFigures = <domain.CatalogFigure>[];
  for (final f in figs) {
    final imageUrl = f.imageKey.trim().isEmpty
        ? null
        : await CatalogImageResolver.resolveFigureAsset(f.imageKey);
    templateFigures.add(
      domain.CatalogFigure(
        templateFigureId: f.id,
        catalogSeriesTemplateId: series.id,
        name: f.displayName,
        imageUrl: imageUrl,
        rarity: f.rarityLabel?.trim().isNotEmpty == true
            ? f.rarityLabel!.trim()
            : (f.isSecret ? 'Secret' : 'Regular'),
        isSecret: f.isSecret,
        taxonomyBrandId: series.brandId,
        taxonomyIpId: series.ipId,
      ),
    );
  }

  return domain.CatalogSeries(
    templateId: series.id,
    name: series.displayName,
    brand: brandLine,
    ipName: ipLine,
    shelfAccent: accent,
    taxonomyBrandId: series.brandId,
    taxonomyIpId: series.ipId,
    figures: templateFigures,
  );
}
