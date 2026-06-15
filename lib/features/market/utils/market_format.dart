// Lightweight USD / percent strings (no intl dependency).

/// Exact dollar amount with comma thousands separator, e.g. `$4,382`.
/// Preferred for shelf / collection value displays where precision matters.
String formatShelfValueUsd(double usd) {
  final rounded = usd.round();
  if (rounded == 0) return '\$0';
  final s = rounded.toString();
  final buf = StringBuffer('\$');
  final offset = s.length % 3;
  for (var i = 0; i < s.length; i++) {
    if (i != 0 && (i - offset) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  return buf.toString();
}
String formatMarketUsd(double usd) {
  final rounded = usd.round();
  if (rounded >= 1000) {
    final k = (rounded / 1000).toStringAsFixed(rounded % 1000 == 0 ? 0 : 1);
    return '\$${k}k';
  }
  return '\$$rounded';
}

String formatPriceChangePercent(double percent) {
  final abs = percent.abs().toStringAsFixed(1);
  if (percent > 0) return '+$abs%';
  if (percent < 0) return '-$abs%';
  return '0.0%';
}

/// User-facing listing date from gateway browse metadata.
String? formatMarketListingDate(DateTime? date) {
  if (date == null) return null;
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  final local = date.toLocal();
  return 'Listed ${months[local.month - 1]} ${local.day}, ${local.year}';
}
