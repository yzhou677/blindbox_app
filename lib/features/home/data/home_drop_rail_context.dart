import 'package:blindbox_app/models/collectible.dart';

/// Honest, fuzzy release copy for the Home rail — derived only from calendar
/// math on [release] vs [clock] (defaults to `DateTime.now()`). No day-level
/// precision in UI labels.
///
/// Northern-hemisphere season groupings are conventional copy buckets only,
/// not geography or street-date claims.
abstract final class HomeDropRailContext {
  static const _monthsLong = <String>[
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  static const _recentPastDays = 21;

  static DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

  static DateTime _clock(DateTime? clock) => clock ?? DateTime.now();

  /// 0 winter (Dec–Feb), 1 spring (Mar–May), 2 summer, 3 fall.
  static int _seasonBucket(DateTime d) {
    final m = d.month;
    if (m == 12 || m <= 2) return 0;
    if (m <= 5) return 1;
    if (m <= 8) return 2;
    return 3;
  }

  static String _seasonDropsLabel(DateTime d) {
    switch (_seasonBucket(d)) {
      case 0:
        return 'Winter drops';
      case 1:
        return 'Spring drops';
      case 2:
        return 'Summer drops';
      default:
        return 'Fall drops';
    }
  }

  /// Disclosure paired with fuzzy labels (tooltips / a11y).
  static const String retailTimingDisclosure = 'Retail dates vary by region and shop.';

  /// Fuzzy window for one drop — no calendar day.
  static String homeReleaseWindowLabel(DateTime release, {DateTime? clock}) {
    final n = _day(_clock(clock));
    final r = _day(release);

    if (r.isAfter(n)) {
      if (r.year == n.year && r.month == n.month) return 'This month';
      if (r.year == n.year) return '${_monthsLong[r.month - 1]} releases';
      return '${_monthsLong[r.month - 1]} ${r.year} releases';
    }

    final days = n.difference(r).inDays;
    if (days <= _recentPastDays) return 'Recently released';
    if (r.year == n.year && r.month == n.month) {
      return '${_monthsLong[r.month - 1]} releases';
    }
    if (r.year == n.year && _seasonBucket(r) == _seasonBucket(n)) {
      return _seasonDropsLabel(r);
    }
    if (r.year == n.year) return '${_monthsLong[r.month - 1]} releases';
    return '${_monthsLong[r.month - 1]} ${r.year} releases';
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
    final w = homeReleaseWindowLabel(latest, clock: clock);
    if (w == 'Recently released') return 'Recently added';
    return w;
  }
}
