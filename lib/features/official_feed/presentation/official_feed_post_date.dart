const _monthShort = [
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

/// Calendar-style post date for compact feed headers (e.g. "Apr 17").
/// Uses the viewer's local calendar day — [publishedAt] should store the
/// official Instagram post instant in UTC (full ISO), not midnight UTC.
String formatOfficialFeedPostDate(DateTime publishedAt) {
  final local = publishedAt.toLocal();
  final month = local.month;
  if (month < 1 || month > 12) {
    return '${local.year}';
  }
  return '${_monthShort[month - 1]} ${local.day}';
}
