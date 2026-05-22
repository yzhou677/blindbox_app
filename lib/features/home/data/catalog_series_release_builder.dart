import 'package:blindbox_app/features/catalog/catalog_seed_loader.dart';
import 'package:blindbox_app/features/catalog/models/catalog_figure.dart';
import 'package:blindbox_app/features/catalog/models/catalog_series.dart';
import 'package:blindbox_app/features/home/domain/series_release.dart';
import 'package:blindbox_app/models/collectible.dart';
import 'package:flutter/material.dart';

/// Builds [SeriesRelease] rows from catalog metadata (imageKeys resolved in UI).
Future<List<SeriesRelease>> buildSeriesReleasesFromCatalog(
  CatalogSeedBundle bundle,
  List<CatalogSeries> seriesList,
) async {
  final figuresBySeries = <String, List<CatalogFigure>>{};
  for (final f in bundle.figures) {
    figuresBySeries.putIfAbsent(f.seriesId, () => []).add(f);
  }
  for (final list in figuresBySeries.values) {
    list.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  }

  final brandNames = {for (final b in bundle.brands) b.id: b.displayName};
  final ipNames = {for (final i in bundle.ips) i.id: i.displayName};

  final built = await Future.wait(
    seriesList.map(
      (series) => _buildOne(
        series,
        figuresBySeries[series.id] ?? const [],
        brandNames,
        ipNames,
      ),
    ),
  );
  return [for (final r in built) if (r != null) r];
}

Future<SeriesRelease?> _buildOne(
  CatalogSeries series,
  List<CatalogFigure> figures,
  Map<String, String> brandNames,
  Map<String, String> ipNames,
) async {
  final releaseDate = _parseReleaseDate(series.releaseDate);
  if (releaseDate == null) return null;

  final brandLabel = brandNames[series.brandId] ?? series.brandId;
  final ipLabel = ipNames[series.ipId] ?? series.ipId;
  final ipLine = '$brandLabel · $ipLabel';
  final accent = _accentForIp(series.ipId);

  final lineup = [
    for (final f in figures)
      ReleaseLineupSlot(
        slotId: f.id,
        name: f.displayName,
        imageKey: f.imageKey,
        isSecret: f.isSecret,
      ),
  ];

  final heroFigure = _pickHeroFigure(figures);
  final heroName = heroFigure?.displayName ?? series.displayName;

  final hero = Collectible(
    id: series.id,
    name: heroName,
    series: series.displayName,
    brand: brandLabel,
    ipLine: ipLine,
    releaseDate: releaseDate,
    imageUrl: '',
    shelfAccent: accent,
  );

  return SeriesRelease(
    dropId: series.id,
    seriesName: series.displayName,
    brand: brandLabel,
    ipLine: ipLine,
    releaseDate: releaseDate,
    seriesImageKey: series.imageKey,
    heroCollectible: hero,
    lineup: lineup,
    taxonomyBrandId: series.brandId,
    taxonomyIpId: series.ipId,
  );
}

CatalogFigure? _pickHeroFigure(List<CatalogFigure> figures) {
  if (figures.isEmpty) return null;
  for (final f in figures) {
    if (!f.isSecret) return f;
  }
  return figures.first;
}

DateTime? _parseReleaseDate(String? iso) {
  if (iso == null || iso.isEmpty) return null;
  try {
    final d = DateTime.parse(iso);
    return DateTime(d.year, d.month, d.day);
  } catch (_) {
    return null;
  }
}

Color? _accentForIp(String ipId) {
  const accents = <String, Color>{
    'the_monsters': Color(0xFFE8F5E9),
    'skullpanda': Color(0xFFE8EAF6),
    'hirono': Color(0xFFFFF3E0),
    'crybaby': Color(0xFFFCE4EC),
    'dimoo': Color(0xFFE3F2FD),
    'molly': Color(0xFFF3E5F5),
    'baby_molly': Color(0xFFF8BBD9),
    'space_molly': Color(0xFFD1C4E9),
  };
  return accents[ipId];
}
