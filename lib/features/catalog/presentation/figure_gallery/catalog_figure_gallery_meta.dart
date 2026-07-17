import 'package:blindbox_app/features/catalog/presentation/figure_gallery/catalog_figure_gallery_item.dart';
import 'package:blindbox_app/features/collection/presentation/figure_secret_rarity_style.dart';
import 'package:flutter/foundation.dart';

final RegExp _galleryOddsTokenPattern = RegExp(r'\d+\s*:\s*\d+');

/// Normalizes pull odds to `1:72` form; null when [raw] is not a ratio label.
String? catalogFigureGalleryNormalizeOdds(String? raw) {
  final label = raw?.trim();
  if (label == null || label.isEmpty) return null;
  if (FigureSecretRarityStyle.parseRatioDenominator(label) == null) {
    return null;
  }
  final match = _galleryOddsTokenPattern.firstMatch(label);
  if (match == null) return null;
  final parts = match.group(0)!.split(':');
  return '${parts[0].trim()}:${parts[1].trim()}';
}

@visibleForTesting
bool catalogFigureGalleryLabelDenotesOdds(String? label) =>
    catalogFigureGalleryNormalizeOdds(label) != null;

/// True when [label] already conveys secret (exact or embedded, e.g. Super Rare Secret).
@visibleForTesting
bool catalogFigureGalleryLabelDenotesSecret(String label) {
  final lower = label.trim().toLowerCase();
  if (lower == 'secret') return true;
  return RegExp(r'\bsecret\b').hasMatch(lower);
}

/// Splits a combined rarity string into descriptive rarity and odds.
({String? rarity, String? odds}) catalogFigureGallerySplitRarityOdds(
  String? raw,
) {
  final label = raw?.trim();
  if (label == null || label.isEmpty) {
    return (rarity: null, odds: null);
  }

  final oddsOnly = catalogFigureGalleryNormalizeOdds(label);
  if (oddsOnly != null && RegExp(r'^\d+\s*:\s*\d+\s*$').hasMatch(label)) {
    return (rarity: null, odds: oddsOnly);
  }

  final oddsMatch = _galleryOddsTokenPattern.firstMatch(label);
  if (oddsMatch == null) {
    return (rarity: label, odds: null);
  }

  final odds = catalogFigureGalleryNormalizeOdds(oddsMatch.group(0)!);
  var rarity =
      '${label.substring(0, oddsMatch.start)}'
      '${label.substring(oddsMatch.end)}';
  rarity = rarity.replaceAll('·', ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
  return (rarity: rarity.isEmpty ? null : rarity, odds: odds);
}

/// Builds the figure rarity/meta segment: rarity → Secret (if needed) → odds.
@visibleForTesting
String? catalogFigureGalleryFigureMetaLine(CatalogFigureGalleryItem item) {
  final parts = <String>[];

  var rarity = item.rarityLabel?.trim();
  var odds = item.oddsLabel?.trim();

  if (odds == null || odds.isEmpty) {
    final split = catalogFigureGallerySplitRarityOdds(rarity);
    rarity = split.rarity;
    odds = split.odds;
  } else if (rarity != null && catalogFigureGalleryLabelDenotesOdds(rarity)) {
    rarity = null;
  }

  if (rarity != null &&
      rarity.isNotEmpty &&
      rarity != 'Regular' &&
      !catalogFigureGalleryLabelDenotesOdds(rarity)) {
    parts.add(rarity);
  }
  if (item.isSecret && !parts.any(catalogFigureGalleryLabelDenotesSecret)) {
    parts.add('Secret');
  }

  final normalizedOdds = catalogFigureGalleryNormalizeOdds(odds);
  if (normalizedOdds != null) {
    parts.add(normalizedOdds);
  }

  if (parts.isEmpty) return null;
  return parts.join(' · ');
}

/// Joins series title and figure meta for the gallery subtitle.
@visibleForTesting
String? catalogFigureGalleryCaptionSecondary({
  required String? metaLine,
  required String? seriesTitle,
}) {
  final series = seriesTitle?.trim();
  final meta = metaLine?.trim();
  if (series != null && series.isNotEmpty) {
    if (meta != null && meta.isNotEmpty) return '$series · $meta';
    return series;
  }
  return meta;
}
