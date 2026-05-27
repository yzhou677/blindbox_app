/// Canonical keys for brand/IP statistics grouping only — never for display.
String canonicalizeStatKey(String input) {
  final lower = input.trim().toLowerCase();
  final sb = StringBuffer();
  for (final c in lower.codeUnits) {
    if (c == 0x20 || c == 0x5F || c == 0x2D) continue;
    sb.writeCharCode(c);
  }
  return sb.toString();
}

/// Merges counts by [canonicalizeStatKey], keeping the first seen display label.
Map<String, int> aggregateBrandBreakdownByCanonicalKey(
  Iterable<({String displayLabel, String rawKey})> entries,
) {
  final groups = <String, ({String displayLabel, int count})>{};
  for (final e in entries) {
    final canon = canonicalizeStatKey(e.rawKey);
    if (canon.isEmpty) continue;
    final existing = groups[canon];
    if (existing == null) {
      groups[canon] = (displayLabel: e.displayLabel, count: 1);
    } else {
      groups[canon] = (
        displayLabel: existing.displayLabel,
        count: existing.count + 1,
      );
    }
  }
  return {
    for (final g in groups.values) g.displayLabel: g.count,
  };
}
