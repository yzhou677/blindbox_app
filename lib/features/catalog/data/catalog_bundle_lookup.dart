import 'package:blindbox_app/features/catalog/catalog_bundle.dart';
import 'package:blindbox_app/features/catalog/models/catalog_brand.dart';
import 'package:blindbox_app/features/catalog/models/catalog_figure.dart';
import 'package:blindbox_app/features/catalog/models/catalog_ip.dart';
import 'package:blindbox_app/features/catalog/models/catalog_series.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart'
    as domain;
import 'package:flutter/material.dart';

/// O(1) catalog indexes — built once per [CatalogSeedBundle] snapshot.
///
/// Used for series template materialization and other hot paths (search rows,
/// preview sheet open) without re-scanning flat figure lists.
final class CatalogBundleLookup {
  CatalogBundleLookup._({
    required this.bundle,
    required Map<String, CatalogSeries> seriesById,
    required Map<String, CatalogBrand> brandById,
    required Map<String, CatalogIp> ipById,
    required Map<String, List<CatalogFigure>> figuresBySeriesId,
  })  : _seriesById = seriesById,
        _brandById = brandById,
        _ipById = ipById,
        _figuresBySeriesId = figuresBySeriesId;

  final CatalogSeedBundle bundle;
  final Map<String, CatalogSeries> _seriesById;
  final Map<String, CatalogBrand> _brandById;
  final Map<String, CatalogIp> _ipById;
  final Map<String, List<CatalogFigure>> _figuresBySeriesId;

  static const _accents = <Color>[
    Color(0xFFE8E4F8),
    Color(0xFFF2E8DC),
    Color(0xFFE4F2EA),
    Color(0xFFE4EDFA),
    Color(0xFFFCE4EC),
    Color(0xFFEAF6FB),
  ];

  factory CatalogBundleLookup.fromBundle(CatalogSeedBundle bundle) {
    final figuresBySeriesId = <String, List<CatalogFigure>>{};
    for (final f in bundle.figures) {
      figuresBySeriesId.putIfAbsent(f.seriesId, () => []).add(f);
    }
    for (final entry in figuresBySeriesId.entries) {
      entry.value.sort((a, b) {
        final o = a.sortOrder.compareTo(b.sortOrder);
        if (o != 0) return o;
        return a.id.compareTo(b.id);
      });
    }
    return CatalogBundleLookup._(
      bundle: bundle,
      seriesById: {for (final s in bundle.series) s.id: s},
      brandById: {for (final b in bundle.brands) b.id: b},
      ipById: {for (final i in bundle.ips) i.id: i},
      figuresBySeriesId: figuresBySeriesId,
    );
  }

  int figureCountInSeries(String seriesId) =>
      _figuresBySeriesId[seriesId]?.length ?? 0;

  /// Collection-domain template for add/preview flows — pure CPU, no I/O.
  domain.CatalogSeries? seriesTemplate(String seriesId) {
    final catalogSeries = _seriesById[seriesId];
    if (catalogSeries == null) return null;

    final figs = _figuresBySeriesId[seriesId];
    if (figs == null || figs.isEmpty) return null;

    final brandLine =
        _brandById[catalogSeries.brandId]?.displayName ?? catalogSeries.brandId;
    final ipLine = _ipById[catalogSeries.ipId]?.displayName ?? catalogSeries.ipId;
    final accent = _accents[seriesId.hashCode.abs() % _accents.length];

    final templateFigures = <domain.CatalogFigure>[];
    for (final f in figs) {
      templateFigures.add(
        domain.CatalogFigure(
          templateFigureId: f.id,
          catalogSeriesTemplateId: catalogSeries.id,
          name: f.displayName,
          catalogImageKey: f.imageKey,
          imageUrl: null,
          rarity: f.rarityLabel?.trim().isNotEmpty == true
              ? f.rarityLabel!.trim()
              : (f.isSecret ? 'Secret' : 'Regular'),
          isSecret: f.isSecret,
          taxonomyBrandId: catalogSeries.brandId,
          taxonomyIpId: catalogSeries.ipId,
        ),
      );
    }

    return domain.CatalogSeries(
      templateId: catalogSeries.id,
      name: catalogSeries.displayName,
      brand: brandLine,
      ipName: ipLine,
      shelfAccent: accent,
      taxonomyBrandId: catalogSeries.brandId,
      taxonomyIpId: catalogSeries.ipId,
      catalogCoverImageKey: catalogSeries.imageKey.trim(),
      figures: templateFigures,
    );
  }
}
