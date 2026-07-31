import 'package:flutter/foundation.dart';

/// How many leading chips fit in [maxRows] given measured/estimated widths.
@immutable
class CollectionShelfFacetCollapsePlan {
  const CollectionShelfFacetCollapsePlan({
    required this.visibleCount,
    required this.hiddenCount,
  });

  /// Number of chips to render while collapsed (selected prioritized upstream).
  final int visibleCount;

  /// Options not shown while collapsed (`Show more (N)`).
  final int hiddenCount;

  bool get needsShowMore => hiddenCount > 0;
}

/// Plans a collapsed facet chip list that fits in at most [maxRows].
///
/// [chipWidths] must align with the display-ordered options (selected first).
/// Spacing is applied between chips on the same row only.
CollectionShelfFacetCollapsePlan planCollectionShelfFacetCollapse({
  required List<double> chipWidths,
  required double maxWidth,
  double spacing = 8,
  int maxRows = 2,
}) {
  assert(maxRows >= 1);
  if (chipWidths.isEmpty) {
    return const CollectionShelfFacetCollapsePlan(
      visibleCount: 0,
      hiddenCount: 0,
    );
  }
  if (!maxWidth.isFinite || maxWidth <= 0) {
    return CollectionShelfFacetCollapsePlan(
      visibleCount: chipWidths.length,
      hiddenCount: 0,
    );
  }

  var row = 0;
  var rowUsed = 0.0;
  var visible = 0;

  for (final rawWidth in chipWidths) {
    final w = rawWidth.clamp(1.0, maxWidth);
    final nextUsed = rowUsed == 0 ? w : rowUsed + spacing + w;
    if (nextUsed <= maxWidth + 0.5) {
      rowUsed = nextUsed;
      visible++;
      continue;
    }
    // Wrap to next row.
    row++;
    if (row >= maxRows) break;
    rowUsed = w;
    visible++;
  }

  final hidden = chipWidths.length - visible;
  return CollectionShelfFacetCollapsePlan(
    visibleCount: visible,
    hiddenCount: hidden < 0 ? 0 : hidden,
  );
}

/// Puts the selected option first, then the rest in original order.
List<T> prioritizeSelectedFacetOption<T>({
  required List<T> ordered,
  required bool Function(T option) isSelected,
}) {
  if (ordered.isEmpty) return ordered;
  T? selected;
  final rest = <T>[];
  for (final o in ordered) {
    if (selected == null && isSelected(o)) {
      selected = o;
    } else {
      rest.add(o);
    }
  }
  if (selected == null) return ordered;
  return [selected, ...rest];
}
