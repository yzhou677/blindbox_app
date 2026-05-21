import 'package:flutter/material.dart';

/// Browse grouping for the read-only catalog tree (not the user shelf).
///
/// [id] is a stable catalog IP key; when a row maps cleanly to Market taxonomy,
/// align [CatalogSeries.taxonomyIpId] with the same string.
@immutable
class IPDefinition {
  const IPDefinition({
    required this.id,
    required this.name,
    required this.catalogSeries,
  });

  final String id;
  final String name;
  final List<CatalogSeries> catalogSeries;
}

/// Official / discoverable catalog template until an API owns this layer.
@immutable
class CatalogSeries {
  const CatalogSeries({
    required this.templateId,
    required this.name,
    required this.brand,
    required this.ipName,
    required this.figures,
    required this.shelfAccent,
    this.notes,
    this.taxonomyBrandId,
    this.taxonomyIpId,
  });

  /// Stable catalog series id (dedupe + future `catalog_series_id`; equals series `imageKey`).
  final String templateId;
  final String name;
  final String brand;
  final String ipName;

  /// Canonical ids aligned with [MarketListing.taxonomyBrandId] / `.taxonomyIpId` when known.
  final String? taxonomyBrandId;
  final String? taxonomyIpId;

  final List<CatalogFigure> figures;
  final Color shelfAccent;
  final String? notes;

  int get figureCount => figures.length;
}

/// One figure slot on a [CatalogSeries] template.
@immutable
class CatalogFigure {
  const CatalogFigure({
    required this.templateFigureId,
    required this.catalogSeriesTemplateId,
    required this.name,
    this.catalogImageKey,
    this.imageUrl,
    required this.rarity,
    required this.isSecret,
    this.taxonomyBrandId,
    this.taxonomyIpId,
  });

  final String templateFigureId;
  final String catalogSeriesTemplateId;
  final String name;

  /// Opaque catalog [imageKey] for Storage/bundled resolve (template-only; not on shelf rows).
  final String? catalogImageKey;
  final String? imageUrl;
  final String rarity;
  final bool isSecret;
  final String? taxonomyBrandId;
  final String? taxonomyIpId;
}

/// User-owned shelf row: catalog clone, marketplace drop import, or fully custom.
@immutable
class ShelfSeries {
  const ShelfSeries({
    required this.id,
    required this.name,
    required this.brand,
    required this.ipName,
    required this.figures,
    required this.shelfAccent,
    this.notes,
    this.catalogTemplateId,
    this.taxonomyBrandId,
    this.taxonomyIpId,
    this.imageKey,
    this.customCoverImageUri,
  });

  /// Unique shelf instance id (per user after persistence).
  final String id;

  /// Series display label (wire: `displayName`; same as catalog [displayName]).
  final String name;
  final String brand;
  final String ipName;

  /// Catalog-aligned cover stem for custom rows (local file via [customCoverImageUri]).
  final String? imageKey;

  /// When non-null, stable key for catalog/drop dedup ([CollectionSnapshot.hasTemplateOnShelf]).
  final String? catalogTemplateId;

  final String? taxonomyBrandId;
  final String? taxonomyIpId;

  final List<ShelfFigure> figures;
  final Color shelfAccent;
  final String? notes;

  /// Local device path or `file:` URI for a user-authored series cover only.
  /// Catalog-backed rows should leave this null.
  final String? customCoverImageUri;

  int get figureCount => figures.length;

  /// User-authored local shelf row (no catalog/drop template key).
  bool get isCustomLocal => catalogTemplateId == null;

  /// Latest-drops style import (mock `drop-*` template keys).
  bool get isDropImport => catalogTemplateId != null && catalogTemplateId!.startsWith('drop-');
}

/// Display + styling helpers for [ShelfFigure] rarity fields.
extension ShelfFigureRarityDisplay on ShelfFigure {
  String get displayRarity {
    final label = rarityLabel?.trim();
    if (label != null && label.isNotEmpty) return label;
    return rarity;
  }

  String? get effectiveRarityLabel {
    final label = rarityLabel?.trim();
    if (label != null && label.isNotEmpty) return label;
    return null;
  }
}

/// One owned figure slot on a [ShelfSeries] row.
@immutable
class ShelfFigure {
  const ShelfFigure({
    required this.id,
    required this.seriesId,
    required this.name,
    this.imageUrl,
    this.localImageUri,
    required this.rarity,
    required this.isSecret,
    this.rarityLabel,
    this.imageKey,
    this.taxonomyBrandId,
    this.taxonomyIpId,
    this.catalogFigureTemplateId,
  });

  final String id;

  /// Parent [ShelfSeries.id] (series instance, never an IP taxonomy id).
  final String seriesId;

  /// Figure display label (wire: `displayName`).
  final String name;

  /// Catalog-resolved asset path, remote art, or legacy placeholder URLs — not [imageKey].
  final String? imageUrl;

  /// User private shelf: local path / `file:` URI only. Never a catalog image key.
  final String? localImageUri;

  /// Opaque art stem for custom rows (pairs with [localImageUri]; catalog uses Storage).
  final String? imageKey;

  /// Short rarity line for UI (Regular / Secret / legacy Custom).
  final String rarity;
  final bool isSecret;

  /// Catalog ratio label when secret (e.g. `1:72`); null for regular custom figures.
  final String? rarityLabel;

  final String? taxonomyBrandId;
  final String? taxonomyIpId;

  /// Source catalog figure id when this row was cloned from a template (sync / API FK).
  final String? catalogFigureTemplateId;
}

/// User progress for one figure slot (wishlist → owned → none); mutually exclusive.
enum FigureCollectionState {
  none,
  wishlist,
  owned,
}

/// Runtime ownership for one shelf figure id ([ShelfFigure.id] instance key).
@immutable
class TrackedFigure {
  const TrackedFigure({
    required this.figureId,
    required this.state,
  });

  final String figureId;
  final FigureCollectionState state;

  bool get owned => state == FigureCollectionState.owned;
  bool get wishlist => state == FigureCollectionState.wishlist;

  TrackedFigure copyWith({FigureCollectionState? state}) {
    return TrackedFigure(
      figureId: figureId,
      state: state ?? this.state,
    );
  }
}

/// Progress for one series from [figureStates].
@immutable
class SeriesProgressCounts {
  const SeriesProgressCounts({
    required this.owned,
    required this.wishlist,
    required this.missing,
  });

  final int owned;
  final int wishlist;
  final int missing;

  double completion(int total) => total <= 0 ? 0 : (owned / total).clamp(0.0, 1.0);
}

SeriesProgressCounts progressForSeries(ShelfSeries series, Map<String, TrackedFigure> states) {
  var o = 0;
  var w = 0;
  var m = 0;
  for (final f in series.figures) {
    final t = states[f.id];
    if (t?.state == FigureCollectionState.owned) {
      o++;
    } else if (t?.state == FigureCollectionState.wishlist) {
      w++;
    } else {
      m++;
    }
  }
  return SeriesProgressCounts(owned: o, wishlist: w, missing: m);
}

/// Deep copy a [CatalogSeries] template onto the shelf with fresh instance ids.
ShelfSeries cloneCatalogSeriesOntoShelf(
  CatalogSeries template,
  String newShelfSeriesId, {
  required String catalogTemplateKey,
}) {
  final newFigures = <ShelfFigure>[];
  for (var i = 0; i < template.figures.length; i++) {
    final f = template.figures[i];
    final newFid = '$newShelfSeriesId-fig-$i';
    newFigures.add(
      ShelfFigure(
        id: newFid,
        seriesId: newShelfSeriesId,
        name: f.name,
        imageUrl: f.imageUrl,
        localImageUri: null,
        rarity: f.rarity,
        isSecret: f.isSecret,
        rarityLabel: _rarityLabelFromLine(f.rarity, f.isSecret),
        imageKey: f.catalogImageKey,
        taxonomyBrandId: f.taxonomyBrandId ?? template.taxonomyBrandId,
        taxonomyIpId: f.taxonomyIpId ?? template.taxonomyIpId,
        catalogFigureTemplateId: f.templateFigureId,
      ),
    );
  }
  return ShelfSeries(
    id: newShelfSeriesId,
    name: template.name,
    brand: template.brand,
    ipName: template.ipName,
    figures: newFigures,
    shelfAccent: template.shelfAccent,
    notes: template.notes,
    catalogTemplateId: catalogTemplateKey,
    taxonomyBrandId: template.taxonomyBrandId,
    taxonomyIpId: template.taxonomyIpId,
    imageKey: catalogTemplateKey,
  );
}

/// Default seed shelf row that mirrors catalog template ids (stable progress keys).
ShelfSeries shelfSeriesMirrorCatalogTemplate(CatalogSeries template) {
  return ShelfSeries(
    id: template.templateId,
    name: template.name,
    brand: template.brand,
    ipName: template.ipName,
    shelfAccent: template.shelfAccent,
    notes: template.notes,
    catalogTemplateId: template.templateId,
    taxonomyBrandId: template.taxonomyBrandId,
    taxonomyIpId: template.taxonomyIpId,
    figures: [
      for (final f in template.figures)
        ShelfFigure(
          id: f.templateFigureId,
          seriesId: template.templateId,
          name: f.name,
          imageUrl: f.imageUrl,
          localImageUri: null,
          rarity: f.rarity,
          isSecret: f.isSecret,
          rarityLabel: _rarityLabelFromLine(f.rarity, f.isSecret),
          imageKey: f.catalogImageKey,
          taxonomyBrandId: f.taxonomyBrandId ?? template.taxonomyBrandId,
          taxonomyIpId: f.taxonomyIpId ?? template.taxonomyIpId,
          catalogFigureTemplateId: f.templateFigureId,
        ),
    ],
  );
}

String? _rarityLabelFromLine(String rarity, bool isSecret) {
  final t = rarity.trim();
  if (RegExp(r'^\d+\s*:\s*\d+\s*$').hasMatch(t)) return t;
  return null;
}

/// User shelf is the source of truth — catalog is suggestions only.
@immutable
class CollectionSnapshot {
  const CollectionSnapshot({
    required this.shelfSeries,
    required this.figureStates,
  });

  final List<ShelfSeries> shelfSeries;
  final Map<String, TrackedFigure> figureStates;

  static CollectionSnapshot emptyTest() => const CollectionSnapshot(
        shelfSeries: [],
        figureStates: {},
      );

  int get trackedSeriesCount => shelfSeries.length;

  int get totalOwnedFigures {
    var c = 0;
    for (final t in figureStates.values) {
      if (t.state == FigureCollectionState.owned) c++;
    }
    return c;
  }

  int get totalWishlistFigures {
    var c = 0;
    for (final t in figureStates.values) {
      if (t.state == FigureCollectionState.wishlist) c++;
    }
    return c;
  }

  int get totalShelfFigures {
    var n = 0;
    for (final s in shelfSeries) {
      n += s.figureCount;
    }
    return n;
  }

  int get averageCompletionPercent {
    if (shelfSeries.isEmpty) return 0;
    var sum = 0.0;
    for (final s in shelfSeries) {
      final p = progressForSeries(s, figureStates);
      sum += p.completion(s.figureCount);
    }
    return ((sum / shelfSeries.length) * 100).round().clamp(0, 100);
  }

  bool get isWarmStart => totalOwnedFigures == 0 && totalWishlistFigures == 0;

  TrackedFigure trackedOrDefault(String figureId) {
    return figureStates[figureId] ?? TrackedFigure(figureId: figureId, state: FigureCollectionState.none);
  }

  /// True if this template (by stable catalog / drop id) already lives on the shelf.
  bool hasTemplateOnShelf(String catalogSeriesTemplateId) {
    for (final s in shelfSeries) {
      if (s.catalogTemplateId == catalogSeriesTemplateId || s.id == catalogSeriesTemplateId) {
        return true;
      }
    }
    return false;
  }
}
