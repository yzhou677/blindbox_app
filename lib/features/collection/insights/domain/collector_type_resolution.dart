import 'package:blindbox_app/features/collection/insights/domain/collector_type_archetype.dart';
import 'package:blindbox_app/features/collection/insights/domain/collector_type_archetypes.dart';
import 'package:blindbox_app/features/collection/insights/domain/collector_type_identity.dart';
import 'package:blindbox_app/features/collection/insights/domain/collector_type_reason_key.dart';
import 'package:blindbox_app/features/collection/insights/domain/collector_type_reason_resolve.dart';
import 'package:blindbox_app/features/collection/insights/domain/collector_type_stats.dart';
import 'package:flutter/foundation.dart';

/// Shared domain outcome of a collector-type resolve pass.
///
/// Reveal, Hero, and future History/Analytics should consume this object —
/// not re-branch on archetype in each surface.
///
/// [confidence] is for [shouldEvolve] only. Do not show it in UI or analytics.
@immutable
class CollectorTypeResolution {
  const CollectorTypeResolution({
    required this.archetypeId,
    required this.score,
    required this.confidence,
    required this.reasonKey,
    required this.signatureHash,
    required this.stats,
    required this.scores,
    this.reasons = const {},
    this.isEvolution = false,
  });

  final CollectorTypeArchetypeId archetypeId;
  final double score;

  /// 0–1 separation of winner vs runner-up. Internal evolution signal only.
  final double confidence;
  final CollectorTypeReasonKey reasonKey;
  final String signatureHash;
  final CollectorTypeStats stats;

  /// Full scoreboard from this pass — used by [shouldEvolve], not by UI.
  final Map<CollectorTypeArchetypeId, double> scores;

  /// Causal key per archetype that scored this pass.
  final Map<CollectorTypeArchetypeId, CollectorTypeReasonKey> reasons;

  /// Set by reveal orchestration after the evolution gate (not by the scorer).
  final bool isEvolution;

  CollectorTypeArchetype get archetype =>
      CollectorTypeArchetypes.byId(archetypeId);

  /// Reason for a specific archetype on this scoreboard (Still / heal path).
  CollectorTypeReasonKey reasonKeyFor(CollectorTypeArchetypeId id) {
    final scored = reasons[id];
    if (scored != null) return scored;
    if (id == archetypeId) {
      return effectiveReasonKey(archetypeId: id, reasonKey: reasonKey);
    }
    return canonicalReasonKeyForArchetype(id);
  }

  CollectorTypeResolution copyWith({bool? isEvolution}) {
    return CollectorTypeResolution(
      archetypeId: archetypeId,
      score: score,
      confidence: confidence,
      reasonKey: reasonKey,
      signatureHash: signatureHash,
      stats: stats,
      scores: scores,
      reasons: reasons,
      isEvolution: isEvolution ?? this.isEvolution,
    );
  }

  /// Durable snapshot persisted until the next reveal.
  CollectorTypeIdentity toIdentity({required DateTime revealedAt}) {
    return CollectorTypeIdentity(
      archetypeId: archetypeId,
      revealedAt: revealedAt,
      signatureHash: signatureHash,
      stats: stats,
      reasonKey: effectiveReasonKey(
        archetypeId: archetypeId,
        reasonKey: reasonKey,
      ),
    );
  }
}
