import 'package:flutter/material.dart';

/// Published character universe (Hirono, Dimoo, …).
@immutable
class IPDefinition {
  const IPDefinition({
    required this.id,
    required this.name,
    required this.series,
  });

  final String id;
  final String name;
  final List<SeriesDefinition> series;
}

/// A retail / story line under an IP (e.g. “The Other One”).
@immutable
class SeriesDefinition {
  const SeriesDefinition({
    required this.id,
    required this.name,
    required this.brand,
    required this.ipName,
    required this.figures,
    required this.shelfAccent,
    this.notes,
  });

  final String id;
  final String name;
  final String brand;

  /// Display IP label (may match parent IP name).
  final String ipName;

  final List<FigureDefinition> figures;
  final Color shelfAccent;

  /// Optional shelf note (common on custom lines).
  final String? notes;

  int get figureCount => figures.length;
}

/// Catalog figure (no ownership here — use [TrackedFigure] in snapshot).
@immutable
class FigureDefinition {
  const FigureDefinition({
    required this.id,
    required this.seriesId,
    required this.ipId,
    required this.name,
    this.imageUrl,
    required this.rarity,
    required this.isSecret,
  });

  final String id;
  final String seriesId;
  final String ipId;
  final String name;

  /// Optional art (network URL mock or null for initials-only UI).
  final String? imageUrl;

  /// e.g. “Regular”, “Secret”, “Ultra”.
  final String rarity;

  final bool isSecret;
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

SeriesProgressCounts progressForSeries(SeriesDefinition series, Map<String, TrackedFigure> states) {
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

/// Immutable library + figure states (Notifier state).
@immutable
class CollectionSnapshot {
  const CollectionSnapshot({
    required this.officialIps,
    required this.customSeries,
    required this.figureStates,
  });

  final List<IPDefinition> officialIps;
  final List<SeriesDefinition> customSeries;
  final Map<String, TrackedFigure> figureStates;

  static CollectionSnapshot emptyTest() => const CollectionSnapshot(
        officialIps: [],
        customSeries: [],
        figureStates: {},
      );

  Iterable<SeriesDefinition> get allOfficialSeries sync* {
    for (final ip in officialIps) {
      for (final s in ip.series) {
        yield s;
      }
    }
  }

  int get trackedSeriesCount {
    var n = 0;
    for (final _ in allOfficialSeries) {
      n++;
    }
    return n + customSeries.length;
  }

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

  int get totalCatalogFigures {
    var n = 0;
    for (final s in allOfficialSeries) {
      n += s.figureCount;
    }
    for (final s in customSeries) {
      n += s.figureCount;
    }
    return n;
  }

  int get averageCompletionPercent {
    final series = [...allOfficialSeries, ...customSeries];
    if (series.isEmpty) return 0;
    var sum = 0.0;
    for (final s in series) {
      final p = progressForSeries(s, figureStates);
      sum += p.completion(s.figureCount);
    }
    return ((sum / series.length) * 100).round().clamp(0, 100);
  }

  bool get isWarmStart => totalOwnedFigures == 0 && totalWishlistFigures == 0;

  TrackedFigure trackedOrDefault(String figureId) {
    return figureStates[figureId] ?? TrackedFigure(figureId: figureId, owned: false, wishlist: false);
  }
}
