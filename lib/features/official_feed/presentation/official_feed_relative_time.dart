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

/// Compact relative time for editorial cards (e.g. "2d ago", "May 18").
String formatOfficialFeedRelativeTime(DateTime publishedAt, {DateTime? clock}) {
  final now = clock ?? DateTime.now();
  final delta = now.difference(publishedAt);
  if (delta.isNegative || delta.inMinutes < 1) {
    return 'Now';
  }
  if (delta.inHours < 1) {
    return '${delta.inMinutes}m ago';
  }
  if (delta.inHours < 48) {
    return '${delta.inHours}h ago';
  }
  if (delta.inDays < 14) {
    return '${delta.inDays}d ago';
  }
  if (delta.inDays < 60) {
    final weeks = delta.inDays ~/ 7;
    return '${weeks}w ago';
  }
  final month = publishedAt.month;
  if (month < 1 || month > 12) {
    return '${publishedAt.year}';
  }
  return '${_monthShort[month - 1]} ${publishedAt.day}';
}
