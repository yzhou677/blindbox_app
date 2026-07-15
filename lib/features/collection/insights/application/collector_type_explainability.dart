import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/collection/insights/application/collector_journey_summary.dart';
import 'package:blindbox_app/features/collection/insights/domain/collector_type_archetype.dart';
import 'package:blindbox_app/features/collection/insights/domain/collector_type_identity.dart';

const int loyalistJourneyBreadthThreshold = 8;
const int loyalistJourneyBreadthDelta = 4;

String? resolveCollectorTypeHelperLine({
  required CollectorTypeIdentity identity,
  required CollectorJourneySummary journey,
  required CollectionSnapshot snapshot,
}) {
  if (identity.archetypeId != CollectorTypeArchetypeId.loyalist) return null;
  final historyBreadth = journey.ipUniversesExplored;
  if (historyBreadth < loyalistJourneyBreadthThreshold) return null;

  final currentSpread = _currentShelfIpSpread(snapshot);
  if (historyBreadth < currentSpread + loyalistJourneyBreadthDelta) return null;

  return 'Current shelf universe count is lower than the historical universe count recorded in Journey.';
}

int _currentShelfIpSpread(CollectionSnapshot snapshot) {
  final ids = <String>{};
  for (final series in snapshot.shelfSeries) {
    final taxonomyIp = series.taxonomyIpId?.trim();
    if (taxonomyIp != null && taxonomyIp.isNotEmpty) {
      ids.add(taxonomyIp);
      continue;
    }
    final fallback = series.ipName.trim().toLowerCase();
    if (fallback.isNotEmpty) ids.add(fallback);
  }
  return ids.length;
}
