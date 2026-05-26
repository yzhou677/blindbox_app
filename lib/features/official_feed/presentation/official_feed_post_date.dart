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
String formatOfficialFeedPostDate(DateTime publishedAt) {
  final month = publishedAt.month;
  if (month < 1 || month > 12) {
    return '${publishedAt.year}';
  }
  return '${_monthShort[month - 1]} ${publishedAt.day}';
}
