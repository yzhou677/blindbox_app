import 'package:blindbox_app/features/collection/data/collection_memory_store.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';

const int substantialJourneyUniverseCount = 8;
const int misleadingRecentJourneyDays = 3;

class CollectorJourneyTopIp {
  const CollectorJourneyTopIp({
    required this.id,
    required this.label,
    required this.seriesCount,
  });

  final String id;
  final String label;
  final int seriesCount;
}

class CollectorJourneySummary {
  const CollectorJourneySummary({
    required this.ipUniversesExplored,
    required this.seriesExploredOverTime,
    required this.topIps,
    required this.journeyAgeLabel,
  });

  final int ipUniversesExplored;
  final int seriesExploredOverTime;
  final List<CollectorJourneyTopIp> topIps;
  final String? journeyAgeLabel;

  bool get hasHistory =>
      ipUniversesExplored > 0 ||
      seriesExploredOverTime > 0 ||
      journeyAgeLabel != null;
}

CollectorJourneySummary buildCollectorJourneySummary({
  required CollectionMemoryData memory,
  required CollectionSnapshot snapshot,
  DateTime? now,
}) {
  final current = now ?? DateTime.now();
  final depth = memory.ipSeriesDepth;
  final universeCount = depth.length;
  final totalSeries = depth.values.fold<int>(0, (sum, count) => sum + count);
  final labelByIpId = _labelByIpId(snapshot);

  final sorted = depth.entries.toList()
    ..sort((a, b) {
      final byCount = b.value.compareTo(a.value);
      if (byCount != 0) return byCount;
      return a.key.compareTo(b.key);
    });
  final topIps = sorted
      .take(3)
      .map(
        (entry) => CollectorJourneyTopIp(
          id: entry.key,
          label: labelByIpId[entry.key] ?? _prettifyIpKey(entry.key),
          seriesCount: entry.value,
        ),
      )
      .toList(growable: false);
  final startedAt = memory.firstSeriesAddedAt;
  final ageDays = startedAt == null
      ? null
      : current.difference(startedAt).inDays;
  final shouldSuppressAge =
      ageDays != null &&
      ageDays >= 0 &&
      ageDays <= misleadingRecentJourneyDays &&
      universeCount >= substantialJourneyUniverseCount;

  return CollectorJourneySummary(
    ipUniversesExplored: universeCount,
    seriesExploredOverTime: totalSeries,
    topIps: topIps,
    journeyAgeLabel: shouldSuppressAge
        ? null
        : formatJourneyAgeLabel(startedAt: startedAt, now: current),
  );
}

/// Display line for a top-explored IP row (presentation only).
String formatCollectorJourneyTopIpLine(String label, int seriesCount) {
  return '$label · $seriesCount series';
}

String? formatJourneyAgeLabel({
  required DateTime? startedAt,
  required DateTime now,
}) {
  if (startedAt == null) return null;
  final days = now.difference(startedAt).inDays;
  if (days < 0) return null;
  if (days < 30) {
    final unit = days == 1 ? 'day' : 'days';
    return '$days $unit ago';
  }
  final months = days ~/ 30;
  if (months < 12) {
    final unit = months == 1 ? 'month' : 'months';
    return '$months $unit ago';
  }
  final years = days ~/ 365;
  final remainingMonths = (days % 365) ~/ 30;
  final yearUnit = years == 1 ? 'year' : 'years';
  if (remainingMonths <= 0) return '$years $yearUnit ago';
  final monthUnit = remainingMonths == 1 ? 'month' : 'months';
  return '$years $yearUnit $remainingMonths $monthUnit ago';
}

Map<String, String> _labelByIpId(CollectionSnapshot snapshot) {
  final map = <String, String>{};
  for (final series in snapshot.shelfSeries) {
    final id = series.taxonomyIpId?.trim();
    final name = series.ipName.trim();
    if (id == null || id.isEmpty || name.isEmpty) continue;
    map.putIfAbsent(id, () => name);
  }
  return map;
}

String _prettifyIpKey(String key) {
  final chunks = key.split(RegExp(r'[_-]+'));
  final words = <String>[];
  for (final chunk in chunks) {
    final part = chunk.trim();
    if (part.isEmpty) continue;
    if (part.length <= 2) {
      words.add(part.toUpperCase());
      continue;
    }
    words.add('${part[0].toUpperCase()}${part.substring(1)}');
  }
  if (words.isEmpty) return key;
  return words.join(' ');
}
