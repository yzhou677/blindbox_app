import 'package:flutter/foundation.dart';

/// Schema version for reveal-frozen [CollectorTypeStats].
///
/// Bump when display math or required fields change so Insights can
/// **derive live stats for display** without rewriting old prefs.
///
/// **2** — Regular Completion = mean `progressRatio`; Master Completion
/// denominator = Secret-bearing series (`masterEligibleSeriesCount`);
/// completed/master tier counts required in JSON.
const int kCollectorTypeStatsVersion = 2;

/// Whether persisted stats may be shown as-is (current schema + required keys).
///
/// Does not mutate storage. Missing keys or older [storedVersion] → false.
bool collectorTypeStatsAreCurrent({
  required int? storedVersion,
  required Map<String, dynamic>? statsJson,
}) {
  if (storedVersion != kCollectorTypeStatsVersion) return false;
  if (statsJson == null) return false;
  const requiredKeys = <String>[
    'completedSeriesCount',
    'masterCompleteSeriesCount',
    'masterEligibleSeriesCount',
    'completionPercent',
  ];
  for (final key in requiredKeys) {
    if (!statsJson.containsKey(key)) return false;
  }
  return true;
}

/// Lightweight stats captured at reveal time (not a live dashboard).
@immutable
class CollectorTypeStats {
  const CollectorTypeStats({
    required this.totalOwned,
    required this.totalWishlist,
    required this.trackedSeries,
    required this.completedSeriesCount,
    required this.masterCompleteSeriesCount,
    required this.masterEligibleSeriesCount,
    required this.completionPercent,
    required this.secretOwned,
    required this.secretSlots,
    required this.brandBreakdown,
    required this.topSeries,
    required this.customSeriesRatio,
  });

  final int totalOwned;
  final int totalWishlist;
  final int trackedSeries;
  final int completedSeriesCount;
  final int masterCompleteSeriesCount;

  /// Secret-bearing series count — Master Completion percentage denominator.
  final int masterEligibleSeriesCount;

  /// Shelf Regular Completion % (mean of canonical per-series progressRatio).
  final int completionPercent;
  final int secretOwned;
  final int secretSlots;
  final Map<String, int> brandBreakdown;
  final List<String> topSeries;
  final double customSeriesRatio;

  Map<String, dynamic> toJson() => {
        'totalOwned': totalOwned,
        'totalWishlist': totalWishlist,
        'trackedSeries': trackedSeries,
        'completedSeriesCount': completedSeriesCount,
        'masterCompleteSeriesCount': masterCompleteSeriesCount,
        'masterEligibleSeriesCount': masterEligibleSeriesCount,
        'completionPercent': completionPercent,
        'secretOwned': secretOwned,
        'secretSlots': secretSlots,
        'brandBreakdown': brandBreakdown,
        'topSeries': topSeries,
        'customSeriesRatio': customSeriesRatio,
      };

  factory CollectorTypeStats.fromJson(Map<String, dynamic> json) {
    final breakdownRaw = json['brandBreakdown'];
    final breakdown = <String, int>{};
    if (breakdownRaw is Map) {
      for (final e in breakdownRaw.entries) {
        if (e.key is String && e.value is int) {
          breakdown[e.key as String] = e.value as int;
        }
      }
    }
    final topRaw = json['topSeries'];
    final top = topRaw is List
        ? [for (final v in topRaw) if (v is String) v]
        : <String>[];

    return CollectorTypeStats(
      totalOwned: (json['totalOwned'] as int?) ?? 0,
      totalWishlist: (json['totalWishlist'] as int?) ?? 0,
      trackedSeries: (json['trackedSeries'] as int?) ?? 0,
      completedSeriesCount: (json['completedSeriesCount'] as int?) ?? 0,
      masterCompleteSeriesCount:
          (json['masterCompleteSeriesCount'] as int?) ?? 0,
      masterEligibleSeriesCount:
          (json['masterEligibleSeriesCount'] as int?) ?? 0,
      completionPercent: (json['completionPercent'] as int?) ?? 0,
      secretOwned: (json['secretOwned'] as int?) ?? 0,
      secretSlots: (json['secretSlots'] as int?) ?? 0,
      brandBreakdown: breakdown,
      topSeries: top,
      customSeriesRatio: (json['customSeriesRatio'] as num?)?.toDouble() ?? 0,
    );
  }
}
