import 'package:blindbox_app/models/collectible.dart';

/// Month-first release copy for the Home rail — derived only from calendar
/// math on [release] vs [clock] (defaults to `DateTime.now()`). No day-level
/// precision in UI labels. Seasonal marketing buckets are intentionally avoided
/// so the time model stays consistent (month-based).
abstract final class HomeDropRailContext {
  /// Latest Drops rail subtitle when driven by the 60-day catalog window.
  static const String recentReleasesRailCaption = 'Recent releases';

  static const _monthsLong = <String>[
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  static const _recentPastDays = 21;

  static DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

  static DateTime _clock(DateTime? clock) => clock ?? DateTime.now();

  /// Disclosure paired with fuzzy labels (tooltips / a11y).
  static const String retailTimingDisclosure = 'Retail dates vary by region and shop.';

  /// Fuzzy window for one drop — month-based, no season names.
  static String homeReleaseWindowLabel(DateTime release, {DateTime? clock}) {
    final n = _day(_clock(clock));
    final r = _day(release);

    if (r.isAfter(n)) {
      if (r.year == n.year && r.month == n.month) return 'This month';
      if (r.year == n.year) return '${_monthsLong[r.month - 1]} releases';
      return '${_monthsLong[r.month - 1]} ${r.year} releases';
    }

    final days = n.difference(r).inDays;
    if (days <= _recentPastDays) return 'Recently added';
    if (r.year == n.year && r.month == n.month) {
      return '${_monthsLong[r.month - 1]} releases';
    }
    if (r.year == n.year) {
      return '${_monthsLong[r.month - 1]} releases';
    }
    return '${_monthsLong[r.month - 1]} ${r.year} releases';
  }

  /// Compact status for detail/meta rows when the rail already shows the calendar window.
  static String releaseStatusTag(DateTime release, {DateTime? clock}) {
    final n = _day(_clock(clock));
    final r = _day(release);
    if (r.isAfter(n)) return 'Upcoming';
    final days = n.difference(r).inDays;
    if (days <= _recentPastDays) return 'New';
    return 'Available';
  }

  /// Tooltip / long-press: fuzzy window only, plus honesty line (no exact day).
  static String homeReleaseTooltip(DateTime release, {DateTime? clock}) {
    final w = homeReleaseWindowLabel(release, clock: clock);
    return '$w · $retailTimingDisclosure';
  }

  /// Latest-drop rail caption from the newest [releaseDate] in the list.
  static String? latestDropsRailCaption(Iterable<Collectible> items, {DateTime? clock}) {
    if (items.isEmpty) return null;
    var latest = items.first.releaseDate;
    for (final c in items.skip(1)) {
      if (c.releaseDate.isAfter(latest)) latest = c.releaseDate;
    }
    final n = _day(_clock(clock));
    final l = _day(latest);

    if (l.year == n.year && l.month == n.month) {
      return l.isAfter(n) ? 'Coming this month' : 'New this month';
    }

    return homeReleaseWindowLabel(latest, clock: clock);
  }
}
