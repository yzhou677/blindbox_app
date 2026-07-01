import 'package:blindbox_app/features/collectible_relationship/application/collectible_relationship_providers.dart';
import 'package:blindbox_app/features/collection/application/collection_notifier.dart';
import 'package:blindbox_app/features/collection/application/shelf_emotional_providers.dart';
import 'package:blindbox_app/features/collection/insights/application/collector_type_providers.dart';
import 'package:blindbox_app/features/collection/presentation/collection_summary_editorial.dart';
import 'package:blindbox_app/features/collection/widgets/collection_summary_section.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Memoized inputs for [CollectionInsightsDashboard] — recomputes only when
/// collection snapshot or emotional providers change.
@immutable
class CollectionInsightsDashboardInputs {
  const CollectionInsightsDashboardInputs({
    required this.stats,
    this.shelfMoodLine,
    this.memoryWhisper,
    this.collectorTypeName,
  });

  final CollectionAggregateStats stats;
  final String? shelfMoodLine;
  final String? memoryWhisper;
  final String? collectorTypeName;
}

final collectionAggregateStatsProvider = Provider<CollectionAggregateStats>((
  ref,
) {
  final snap = ref.watch(collectionNotifierProvider);
  return CollectionAggregateStats.fromSnapshot(snap);
});

final collectionInsightsDashboardInputsProvider =
    Provider<CollectionInsightsDashboardInputs>((ref) {
      final stats = ref.watch(collectionAggregateStatsProvider);
      final interpretationLine = ref.watch(shelfInterpretationLineProvider);
      final snap = ref.watch(collectionNotifierProvider);
      final shelfMoodLine = interpretationLine.isNotEmpty
          ? interpretationLine
          : CollectionSummaryEditorial.shelfMoodLine(snap);
      final memoryWhisper = ref.watch(shelfMemoryWhisperProvider);
      final relationshipWhisper = ref.watch(shelfRelationshipWhisperProvider);
      final collectorIdentity = ref.watch(collectorTypeIdentityProvider);

      return CollectionInsightsDashboardInputs(
        stats: stats,
        shelfMoodLine: shelfMoodLine,
        memoryWhisper: memoryWhisper ?? relationshipWhisper,
        collectorTypeName: collectorIdentity?.archetype.displayName,
      );
    });
