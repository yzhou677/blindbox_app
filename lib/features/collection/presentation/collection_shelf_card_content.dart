import 'package:blindbox_app/features/catalog/catalog_bundle.dart';
import 'package:blindbox_app/features/catalog/models/catalog_series.dart'
    as catalog;
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/collection/presentation/collection_shelf_browse.dart';
import 'package:blindbox_app/features/collection/presentation/collection_shelf_layout.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

/// Maximum optional metadata fields shown on a Series Card / chosen in Layout.
const int kMaxCollectionShelfCardContentSelections = 2;

/// Optional Series Card metadata the collector can enable once for My Collection.
///
/// Permanent card content (artwork, name, progress) is never represented here.
/// Selection is shared across Grid, Compact Grid, and List.
enum CollectionShelfCardContentField {
  /// Catalog **U.S.** release date (`releaseDate`), never a global release.
  usReleaseDate,

  /// Display Brand used by Collection brand filtering.
  brand,

  /// Display IP used by Collection IP filtering.
  ip,

  /// Count of figures in wishlist state for this series (`> 0` only).
  wishlistCount,

  /// Total extra owned copies: Σ max(ownedQuantity − 1, 0) across figures.
  duplicateCount,
}

extension CollectionShelfCardContentFieldLabels
    on CollectionShelfCardContentField {
  /// Stable SharedPreferences / JSON id.
  String get id => switch (this) {
    CollectionShelfCardContentField.usReleaseDate => 'us_release_date',
    CollectionShelfCardContentField.brand => 'brand',
    CollectionShelfCardContentField.ip => 'ip',
    CollectionShelfCardContentField.wishlistCount => 'wishlist_count',
    CollectionShelfCardContentField.duplicateCount => 'duplicate_count',
  };

  String get sheetLabel => switch (this) {
    CollectionShelfCardContentField.usReleaseDate => 'U.S. Release Date',
    CollectionShelfCardContentField.brand => 'Brand',
    CollectionShelfCardContentField.ip => 'IP',
    CollectionShelfCardContentField.wishlistCount => 'Wishlist Count',
    CollectionShelfCardContentField.duplicateCount => 'Duplicate Count',
  };

  IconData get sheetIcon => switch (this) {
    CollectionShelfCardContentField.usReleaseDate =>
      Symbols.calendar_month_rounded,
    CollectionShelfCardContentField.brand => Symbols.sell_rounded,
    CollectionShelfCardContentField.ip => Symbols.star_rounded,
    CollectionShelfCardContentField.wishlistCount => Symbols.favorite_rounded,
    CollectionShelfCardContentField.duplicateCount =>
      Symbols.filter_none_rounded,
  };

  static CollectionShelfCardContentField? tryParse(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    for (final value in CollectionShelfCardContentField.values) {
      if (value.id == raw || value.name == raw) return value;
    }
    return null;
  }
}

/// Ordered optional-field preference shared by every Collection layout.
@immutable
class CollectionShelfCardContentSelection {
  const CollectionShelfCardContentSelection([this.ordered = const []]);

  static const empty = CollectionShelfCardContentSelection();

  final List<CollectionShelfCardContentField> ordered;

  bool get isEmpty => ordered.isEmpty;

  bool contains(CollectionShelfCardContentField field) =>
      ordered.contains(field);

  int availableSelectedCount(Set<CollectionShelfCardContentField> available) {
    var n = 0;
    for (final field in ordered) {
      if (available.contains(field)) n++;
    }
    return n;
  }

  bool canSelect(
    CollectionShelfCardContentField field,
    Set<CollectionShelfCardContentField> available,
  ) {
    if (!available.contains(field)) return false;
    if (contains(field)) return true;
    return availableSelectedCount(available) <
        kMaxCollectionShelfCardContentSelections;
  }

  /// Toggle [field] among currently [available] options.
  ///
  /// Unavailable stored prefs are preserved and do not count toward the limit.
  /// Adding when an unavailable slot occupies a stored entry may grow the list
  /// past two; [sanitizePreservingUnavailable] / [resolveDisplayFields] cap
  /// rendered available fields at two using list order.
  CollectionShelfCardContentSelection toggle(
    CollectionShelfCardContentField field, {
    required Set<CollectionShelfCardContentField> available,
  }) {
    if (!available.contains(field)) return this;
    if (contains(field)) {
      return CollectionShelfCardContentSelection([
        for (final f in ordered)
          if (f != field) f,
      ]);
    }
    if (availableSelectedCount(available) >=
        kMaxCollectionShelfCardContentSelections) {
      return this;
    }
    return CollectionShelfCardContentSelection([...ordered, field]);
  }

  /// Drop unknown / duplicate ids and resolve over-limit available picks.
  ///
  /// Keeps unavailable fields so they can reappear; among available fields,
  /// keeps the earliest [kMaxCollectionShelfCardContentSelections] in order.
  CollectionShelfCardContentSelection sanitizePreservingUnavailable(
    Set<CollectionShelfCardContentField> available,
  ) {
    final seen = <CollectionShelfCardContentField>{};
    final kept = <CollectionShelfCardContentField>[];
    var availableKept = 0;
    for (final field in ordered) {
      if (!seen.add(field)) continue;
      final isAvailable = available.contains(field);
      if (isAvailable) {
        if (availableKept >= kMaxCollectionShelfCardContentSelections) {
          continue;
        }
        availableKept++;
      }
      kept.add(field);
    }
    return CollectionShelfCardContentSelection(kept);
  }

  /// Decode a JSON list of stable ids; unknown values ignored; hard-cap at 2
  /// when no availability context is supplied (codec / reload path).
  static CollectionShelfCardContentSelection decode(Object? raw) {
    if (raw is! List) return empty;
    final seen = <CollectionShelfCardContentField>{};
    final out = <CollectionShelfCardContentField>[];
    for (final item in raw) {
      final field = CollectionShelfCardContentFieldLabels.tryParse(
        item is String ? item : null,
      );
      if (field == null || !seen.add(field)) continue;
      out.add(field);
      // All five fields is the natural unique cap (unavailable + available).
      if (out.length >= CollectionShelfCardContentField.values.length) break;
    }
    return CollectionShelfCardContentSelection(out);
  }

  List<String> toJsonIds() => [for (final f in ordered) f.id];

  @override
  bool operator ==(Object other) {
    return other is CollectionShelfCardContentSelection &&
        listEquals(other.ordered, ordered);
  }

  @override
  int get hashCode => Object.hashAll(ordered);
}

/// Shared Collection Card Content preference (one selection for all layouts).
///
/// ## Storage formats
/// - **Current:** JSON array of field ids, e.g. `["brand","ip"]`
/// - **Legacy:** per-layout map, e.g. `{"grid":["brand"],"list":["ip"]}` —
///   normalized to a single selection (prefer [preferredLayout], else first
///   non-empty in [CollectionShelfLayout] order).
@immutable
class CollectionShelfCardContentPrefs {
  const CollectionShelfCardContentPrefs([
    this.selection = CollectionShelfCardContentSelection.empty,
  ]);

  static const empty = CollectionShelfCardContentPrefs();

  final CollectionShelfCardContentSelection selection;

  bool get isEmpty => selection.isEmpty;

  CollectionShelfCardContentPrefs copyWithSelection(
    CollectionShelfCardContentSelection selection,
  ) {
    return CollectionShelfCardContentPrefs(selection);
  }

  /// Decodes shared or legacy per-layout payloads into one selection.
  static CollectionShelfCardContentPrefs decode(
    Object? raw, {
    CollectionShelfLayout? preferredLayout,
  }) {
    if (raw is List) {
      return CollectionShelfCardContentPrefs(
        CollectionShelfCardContentSelection.decode(raw),
      );
    }
    if (raw is Map) {
      final map = raw;
      // Forward-compatible shared object form.
      if (map['fields'] is List) {
        return CollectionShelfCardContentPrefs(
          CollectionShelfCardContentSelection.decode(map['fields']),
        );
      }
      if (preferredLayout != null) {
        final preferred = CollectionShelfCardContentSelection.decode(
          map[preferredLayout.name],
        );
        if (!preferred.isEmpty) {
          return CollectionShelfCardContentPrefs(preferred);
        }
      }
      for (final layout in CollectionShelfLayout.values) {
        final sel = CollectionShelfCardContentSelection.decode(
          map[layout.name],
        );
        if (!sel.isEmpty) return CollectionShelfCardContentPrefs(sel);
      }
    }
    return empty;
  }

  /// Persists as a flat id list (not keyed by layout).
  List<String> toJson() => selection.toJsonIds();

  @override
  bool operator ==(Object other) {
    return other is CollectionShelfCardContentPrefs &&
        other.selection == selection;
  }

  @override
  int get hashCode => selection.hashCode;
}

/// One resolved metadata line ready for card presentation.
@immutable
class CollectionShelfCardContentLine {
  const CollectionShelfCardContentLine({
    required this.field,
    required this.text,
    required this.icon,
  });

  final CollectionShelfCardContentField field;
  final String text;
  final IconData icon;
}

/// Short English months for compact card copy (`U.S. Jul 30, 2026`).
const _cardUsReleaseMonths = <String>[
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// Compact card label for a catalog U.S. release date; null when missing/bad.
String? formatUsReleaseDateCardLine(DateTime? date) {
  if (date == null) return null;
  final year = date.year;
  final month = date.month;
  final day = date.day;
  if (month < 1 || month > 12 || day < 1 || day > 31) return null;
  if (year < 1990 || year > 2100) return null;
  return 'U.S. ${_cardUsReleaseMonths[month - 1]} $day, $year';
}

String? _brandDisplay(ShelfSeries series) {
  final brand = series.brand.trim();
  return brand.isEmpty ? null : brand;
}

String? _ipDisplay(ShelfSeries series) {
  final ip = shelfSeriesIpLabel(series).trim();
  return ip.isEmpty ? null : ip;
}

DateTime? _usReleaseDate(
  ShelfSeries series, {
  CatalogSeedBundle? catalog,
  Map<String, catalog.CatalogSeries>? catalogSeriesById,
}) {
  final lookup =
      catalogSeriesById ??
      (catalog == null ? null : {for (final s in catalog.series) s.id: s});
  return catalogReleaseDateForShelfSeries(series, catalogSeriesById: lookup);
}

/// Whether [field] has a meaningful value on [series] (card hide rule).
bool seriesHasCardContentValue(
  CollectionShelfCardContentField field,
  ShelfSeries series,
  Map<String, TrackedFigure> states, {
  CatalogSeedBundle? catalog,
  Map<String, catalog.CatalogSeries>? catalogSeriesById,
  SeriesProgressCounts? progress,
}) {
  final counts = progress ?? progressForSeries(series, states);
  switch (field) {
    case CollectionShelfCardContentField.usReleaseDate:
      return formatUsReleaseDateCardLine(
            _usReleaseDate(
              series,
              catalog: catalog,
              catalogSeriesById: catalogSeriesById,
            ),
          ) !=
          null;
    case CollectionShelfCardContentField.brand:
      return _brandDisplay(series) != null;
    case CollectionShelfCardContentField.ip:
      return _ipDisplay(series) != null;
    case CollectionShelfCardContentField.wishlistCount:
      return counts.wishlist > 0;
    case CollectionShelfCardContentField.duplicateCount:
      return counts.duplicateCount > 0;
  }
}

String? resolveCardContentText(
  CollectionShelfCardContentField field,
  ShelfSeries series,
  Map<String, TrackedFigure> states, {
  CatalogSeedBundle? catalog,
  Map<String, catalog.CatalogSeries>? catalogSeriesById,
  SeriesProgressCounts? progress,
}) {
  final counts = progress ?? progressForSeries(series, states);
  switch (field) {
    case CollectionShelfCardContentField.usReleaseDate:
      return formatUsReleaseDateCardLine(
        _usReleaseDate(
          series,
          catalog: catalog,
          catalogSeriesById: catalogSeriesById,
        ),
      );
    case CollectionShelfCardContentField.brand:
      return _brandDisplay(series);
    case CollectionShelfCardContentField.ip:
      return _ipDisplay(series);
    case CollectionShelfCardContentField.wishlistCount:
      final n = counts.wishlist;
      if (n <= 0) return null;
      return n == 1 ? '1 wished' : '$n wished';
    case CollectionShelfCardContentField.duplicateCount:
      // Total extra copies: Σ max(ownedQuantity − 1, 0) — see TrackedFigure.
      final n = counts.duplicateCount;
      if (n <= 0) return null;
      return n == 1 ? '1 duplicate' : '$n duplicates';
  }
}

/// Fields that have usable data on at least one series in the shelf.
Set<CollectionShelfCardContentField> availableCollectionShelfCardContentFields({
  required List<ShelfSeries> shelfSeries,
  required Map<String, TrackedFigure> figureStates,
  CatalogSeedBundle? catalog,
  ShelfBrowseProgressLookup? progress,
}) {
  final available = <CollectionShelfCardContentField>{};
  final catalogById = catalog == null
      ? null
      : {for (final s in catalog.series) s.id: s};
  for (final field in CollectionShelfCardContentField.values) {
    for (final series in shelfSeries) {
      if (seriesHasCardContentValue(
        field,
        series,
        figureStates,
        catalog: catalog,
        catalogSeriesById: catalogById,
        progress: progress?.forSeries(series),
      )) {
        available.add(field);
        break;
      }
    }
  }
  return available;
}

/// Preference order → at most two lines that have values on this series.
List<CollectionShelfCardContentField> resolveDisplayFields(
  CollectionShelfCardContentSelection selection,
  ShelfSeries series,
  Map<String, TrackedFigure> states, {
  CatalogSeedBundle? catalog,
  SeriesProgressCounts? progress,
}) {
  final out = <CollectionShelfCardContentField>[];
  final catalogById = catalog == null
      ? null
      : {for (final s in catalog.series) s.id: s};
  final counts = progress ?? progressForSeries(series, states);
  for (final field in selection.ordered) {
    if (!seriesHasCardContentValue(
      field,
      series,
      states,
      catalog: catalog,
      catalogSeriesById: catalogById,
      progress: counts,
    )) {
      continue;
    }
    out.add(field);
    if (out.length >= kMaxCollectionShelfCardContentSelections) break;
  }
  return out;
}

List<CollectionShelfCardContentLine> resolveCardContentLines(
  CollectionShelfCardContentSelection selection,
  ShelfSeries series,
  Map<String, TrackedFigure> states, {
  CatalogSeedBundle? catalog,
  SeriesProgressCounts? progress,
}) {
  final counts = progress ?? progressForSeries(series, states);
  final catalogById = catalog == null
      ? null
      : {for (final s in catalog.series) s.id: s};
  final lines = <CollectionShelfCardContentLine>[];
  for (final field in resolveDisplayFields(
    selection,
    series,
    states,
    catalog: catalog,
    progress: counts,
  )) {
    final text = resolveCardContentText(
      field,
      series,
      states,
      catalog: catalog,
      catalogSeriesById: catalogById,
      progress: counts,
    );
    if (text == null || text.isEmpty) continue;
    lines.add(
      CollectionShelfCardContentLine(
        field: field,
        text: text,
        icon: field.sheetIcon,
      ),
    );
  }
  return lines;
}
