import 'package:blindbox_app/features/collection/insights/domain/collector_type_archetype.dart';
import 'package:blindbox_app/features/collection/insights/domain/collector_type_reason_key.dart';

/// Maps a winning archetype to its default causal key when a scored reason
/// is missing (legacy identities, Still without a fresh reason row).
CollectorTypeReasonKey canonicalReasonKeyForArchetype(
  CollectorTypeArchetypeId id,
) {
  return switch (id) {
    CollectorTypeArchetypeId.dreamer => CollectorTypeReasonKey.highWishlist,
    CollectorTypeArchetypeId.hunter => CollectorTypeReasonKey.manySecrets,
    CollectorTypeArchetypeId.completionist =>
      CollectorTypeReasonKey.deepCompletion,
    CollectorTypeArchetypeId.loyalist => CollectorTypeReasonKey.dominantUniverse,
    CollectorTypeArchetypeId.curator =>
      CollectorTypeReasonKey.intentionalSpread,
    CollectorTypeArchetypeId.trendChaser => CollectorTypeReasonKey.freshDrops,
    CollectorTypeArchetypeId.archivist => CollectorTypeReasonKey.livingArchive,
    CollectorTypeArchetypeId.minimalist => CollectorTypeReasonKey.compactShelf,
    CollectorTypeArchetypeId.wanderer => CollectorTypeReasonKey.stillUnfolding,
    CollectorTypeArchetypeId.stylist => CollectorTypeReasonKey.composedShelf,
    CollectorTypeArchetypeId.daydreamCollector =>
      CollectorTypeReasonKey.wishlistDominates,
    CollectorTypeArchetypeId.luckyOne =>
      CollectorTypeReasonKey.fortunateSecrets,
  };
}

/// Heals legacy / mismatched identity reason keys for display + persist.
///
/// `stillUnfolding` is only valid for Wanderer. Any other archetype with that
/// default must use the archetype’s canonical Because key.
CollectorTypeReasonKey effectiveReasonKey({
  required CollectorTypeArchetypeId archetypeId,
  required CollectorTypeReasonKey reasonKey,
}) {
  if (reasonKey != CollectorTypeReasonKey.stillUnfolding) return reasonKey;
  if (archetypeId == CollectorTypeArchetypeId.wanderer) {
    return CollectorTypeReasonKey.stillUnfolding;
  }
  return canonicalReasonKeyForArchetype(archetypeId);
}
