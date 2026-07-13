import 'package:blindbox_app/features/collection/insights/domain/collector_type_resolution.dart';
import 'package:blindbox_app/features/collection/insights/domain/collector_type_reveal_record.dart';

/// Whether Insights should encourage another Reveal.
///
/// Pure gate: compares **live shelf composition + resolver policy** to the
/// last reveal. Does not mutate persistence.
///
/// True when a reveal exists and any of:
/// - [persistedResolverVersion] is missing or ≠ [currentResolverVersion]
/// - live signature ≠ persisted signature (shelf composition drifted)
/// - persisted stats schema is outdated / missing required fields
///   ([persistedStatsAreCurrent] == false)
///
/// Signature / this flag answer **When** a reveal is required only.
/// They never decide the reveal **result** — once the user reveals while this
/// is true, [resolveCollectorType] is sole authority over persisted identity.
///
/// **Not** compared: live candidate archetype vs revealed title.
bool computeCollectorTypeNeedsReveal({
  required bool hasRevealed,
  required String? persistedSignatureHash,
  required String? persistedResolverVersion,
  required CollectorTypeResolution liveCandidate,
  String currentResolverVersion = kCollectorTypeResolverVersion,
  bool persistedStatsAreCurrent = true,
}) {
  if (!hasRevealed) return false;

  if (!persistedStatsAreCurrent) return true;

  if (persistedResolverVersion == null ||
      persistedResolverVersion.isEmpty ||
      persistedResolverVersion != currentResolverVersion) {
    return true;
  }

  final storedHash = persistedSignatureHash;
  if (storedHash == null || storedHash.isEmpty) return true;

  if (liveCandidate.signatureHash != storedHash) return true;

  return false;
}
