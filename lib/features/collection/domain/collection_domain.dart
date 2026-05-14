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

  /// Stable catalog series id (dedupe + future `catalog_series_id`).
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
    this.imageUrl,
    required this.rarity,
    required this.isSecret,
    this.taxonomyBrandId,
    this.taxonomyIpId,
  });

  final String templateFigureId;
  final String catalogSeriesTemplateId;
  final String name;
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
  });

  /// Unique shelf instance id (per user after persistence).
  final String id;
  final String name;
  final String brand;
  final String ipName;

  /// When non-null, stable key for catalog/drop dedup ([CollectionSnapshot.hasTemplateOnShelf]).
  final String? catalogTemplateId;

  final String? taxonomyBrandId;
  final String? taxonomyIpId;

  final List<ShelfFigure> figures;
  final Color shelfAccent;
  final String? notes;

  int get figureCount => figures.length;

  /// User-authored local shelf row (no catalog/drop template key).
  bool get isCustomLocal => catalogTemplateId == null;

  /// Latest-drops style import (mock `drop-*` template keys).
  bool get isDropImport => catalogTemplateId != null && catalogTemplateId!.startsWith('drop-');
}

/// One owned figure slot on a [ShelfSeries] row.
@immutable
class ShelfFigure {
  const ShelfFigure({
    required this.id,
    required this.seriesId,
    required this.name,
    this.imageUrl,
    required this.rarity,
    required this.isSecret,
    this.taxonomyBrandId,
    this.taxonomyIpId,
    this.catalogFigureTemplateId,
  });

  final String id;

  /// Parent [ShelfSeries.id] (series instance, never an IP taxonomy id).
  final String seriesId;
  final String name;
  final String? imageUrl;
  final String rarity;
  final bool isSecret;

  final String? taxonomyBrandId;
  final String? taxonomyIpId;

  /// Source catalog figure id when this row was cloned from a template (sync / API FK).
  final String? catalogFigureTemplateId;
}

/// Runtime ownership for one figure id.
@immutable
class TrackedFigure {
  const TrackedFigure({
    required this.figureId,
    required this.owned,
    required this.wishlist,
  });

  final String figureId;
  final bool owned;
  final bool wishlist;

  TrackedFigure copyWith({bool? owned, bool? wishlist}) {
    return TrackedFigure(
      figureId: figureId,
      owned: owned ?? this.owned,
      wishlist: wishlist ?? this.wishlist,
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
    if (t?.owned == true) {
      o++;
    } else if (t?.wishlist == true) {
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
        rarity: f.rarity,
        isSecret: f.isSecret,
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
          rarity: f.rarity,
          isSecret: f.isSecret,
          taxonomyBrandId: f.taxonomyBrandId ?? template.taxonomyBrandId,
          taxonomyIpId: f.taxonomyIpId ?? template.taxonomyIpId,
          catalogFigureTemplateId: f.templateFigureId,
        ),
    ],
  );
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
      if (t.owned) c++;
    }
    return c;
  }

  int get totalWishlistFigures {
    var c = 0;
    for (final t in figureStates.values) {
      if (t.wishlist) c++;
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
    return figureStates[figureId] ?? TrackedFigure(figureId: figureId, owned: false, wishlist: false);
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
