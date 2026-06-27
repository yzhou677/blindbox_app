import 'package:blindbox_app/features/collection/insights/application/collector_journey_summary.dart';

/// Quiet dashboard label for when a collector type was last revealed.
String? formatCollectorTypeUpdatedLabel({
  required DateTime revealedAt,
  DateTime? now,
}) {
  final current = now ?? DateTime.now();
  final days = current.difference(revealedAt).inDays;
  if (days < 0) return null;

  if (days == 0) return 'Updated today';
  if (days == 1) return 'Updated yesterday';

  final age = formatJourneyAgeLabel(startedAt: revealedAt, now: current);
  if (age == null) return null;
  return 'Updated $age';
}
