/// Lightweight USD / percent strings (no intl dependency).
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
