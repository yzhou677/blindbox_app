import 'package:blindbox_app/features/collection/data/collection_memory_store.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/collection/domain/series_completion_resolution.dart';
import 'package:flutter/foundation.dart';

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

/// One memorable moment for Journey — not a stats counter.
enum JourneyMemoryKind { masterComplete, completedSeries, firstSecret }

/// Latest memorable moment from existing [CollectionMemoryData] only.
@immutable
class JourneyLatestMemory {
  const JourneyLatestMemory({
    required this.kind,
    required this.observedAt,
    required this.ageLabel,
    this.seriesName,
  });

  final JourneyMemoryKind kind;
  final DateTime observedAt;
  final String ageLabel;
  final String? seriesName;
}

/// Live collection-history summary — never frozen into a Collector Type reveal.
///
/// Collector Journey is intentionally LIVE (recomputed from memory + shelf),
/// but its **metrics are historical by design** — not current shelf composition.
///
/// - **Started** → first series added (`firstSeriesAddedAt`)
/// - **Explored IP universes** → unique IPs ever explored (`ipSeriesDepth.length`);
///   append-only; does **not** decrease when series are removed
/// - **Latest Memory** → most meaningful existing moment (omit if none)
/// - **Identity** (elsewhere) → snapshot at last reveal
///
/// Journey tells the collector’s path over time. Do not “fix” Explored to
/// match current unique IPs on the shelf.
///
/// Unlike Collector Type and other insight cards,
/// Journey is not part of the Reveal snapshot.
///
/// Presentation keeps **stable field slots** for Started / Explored; null/zero
/// values still occupy their place. Latest Memory is the diary exception —
/// omit the row entirely when no moment exists.
///
/// **Diary principle:** surface at most one or two memorable moments — never
/// grow into a stats dashboard (Started + Latest Memory today; more beats later,
/// but always curated).
class CollectorJourneySummary {
  const CollectorJourneySummary({
    required this.ipUniversesExplored,
    required this.seriesExploredOverTime,
    required this.topIps,
    required this.journeyAgeLabel,
    this.latestMemory,
  });

  /// Unique IPs ever recorded in [CollectionMemoryData.ipSeriesDepth] — historical,
  /// not “IPs currently on the shelf.”
  final int ipUniversesExplored;
  final int seriesExploredOverTime;
  final List<CollectorJourneyTopIp> topIps;
  final String? journeyAgeLabel;

  /// Most meaningful existing moment, or null when none apply.
  final JourneyLatestMemory? latestMemory;

  bool get hasHistory =>
      ipUniversesExplored > 0 ||
      seriesExploredOverTime > 0 ||
      journeyAgeLabel != null ||
      latestMemory != null;
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

  return CollectorJourneySummary(
    ipUniversesExplored: universeCount,
    seriesExploredOverTime: totalSeries,
    topIps: topIps,
    // Always surface Started when memory has a start date — Journey answers
    // both "when did collecting begin?" and "how many universes explored?"
    journeyAgeLabel: formatJourneyAgeLabel(
      startedAt: memory.firstSeriesAddedAt,
      now: current,
    ),
    latestMemory: pickLatestJourneyMemory(
      memory: memory,
      snapshot: snapshot,
      now: current,
    ),
  );
}

/// Priority: Master Complete (if latest completion is still master) →
/// Completed Series → First Secret. No new persistence.
JourneyLatestMemory? pickLatestJourneyMemory({
  required CollectionMemoryData memory,
  required CollectionSnapshot snapshot,
  DateTime? now,
}) {
  final current = now ?? DateTime.now();
  final completedId = memory.lastCompletedSeriesId?.trim();
  final completedAt = memory.lastCompletedAt;
  if (completedId != null && completedId.isNotEmpty && completedAt != null) {
    ShelfSeries? series;
    for (final s in snapshot.shelfSeries) {
      if (s.id == completedId) {
        series = s;
        break;
      }
    }
    final name = series?.name.trim();
    final seriesName = (name != null && name.isNotEmpty) ? name : null;
    final isMaster =
        series != null &&
        resolveSeriesCompletion(series, snapshot.figureStates).isMasterComplete;
    final ageLabel = formatJourneyAgeLabel(
      startedAt: completedAt,
      now: current,
    );
    if (ageLabel == null) return null;
    return JourneyLatestMemory(
      kind: isMaster
          ? JourneyMemoryKind.masterComplete
          : JourneyMemoryKind.completedSeries,
      observedAt: completedAt,
      ageLabel: ageLabel,
      seriesName: seriesName,
    );
  }

  final firstSecretAt = memory.firstSecretOwnedAt;
  if (firstSecretAt != null) {
    final ageLabel = formatJourneyAgeLabel(
      startedAt: firstSecretAt,
      now: current,
    );
    if (ageLabel == null) return null;
    return JourneyLatestMemory(
      kind: JourneyMemoryKind.firstSecret,
      observedAt: firstSecretAt,
      ageLabel: ageLabel,
    );
  }

  return null;
}

String? formatJourneyAgeLabel({
  required DateTime? startedAt,
  required DateTime now,
}) {
  if (startedAt == null) return null;
  final days = now.difference(startedAt).inDays;
  if (days < 0) return null;
  if (days == 0) return 'Today';
  if (days == 1) return 'Yesterday';
  if (days < 30) {
    return '$days days ago';
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
