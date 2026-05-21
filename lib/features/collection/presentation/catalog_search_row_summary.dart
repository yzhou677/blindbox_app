/// One-line, shelf-friendly subtitle for catalog search result rows.
///
/// - Single standout figure hit → `Includes {name}`
/// - Everything else → `{n} figures` (+ ` • chase included` when relevant)
String catalogSearchRowSummary({
  required int figureCount,
  required bool hasChase,
  required Set<String> matchedFigureNames,
}) {
  if (matchedFigureNames.length == 1) {
    return 'Includes ${matchedFigureNames.first}';
  }

  final count = figureCount == 1 ? '1 figure' : '$figureCount figures';
  if (hasChase) return '$count • chase included';
  return count;
}
