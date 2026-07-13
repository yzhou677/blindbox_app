import 'package:blindbox_app/features/collection/insights/domain/collector_type_archetype.dart';
import 'package:blindbox_app/features/collection/insights/domain/collector_type_archetypes.dart';
import 'package:blindbox_app/features/collection/insights/domain/collector_type_reason_key.dart';
import 'package:blindbox_app/features/collection/insights/domain/collector_type_reason_resolve.dart';
import 'package:blindbox_app/features/collection/insights/domain/collector_type_stats.dart';
import 'package:flutter/foundation.dart';

/// Persisted collector identity — stable until the user re-reveals.
@immutable
class CollectorTypeIdentity {
  const CollectorTypeIdentity({
    required this.archetypeId,
    required this.revealedAt,
    required this.signatureHash,
    required this.stats,
    this.reasonKey = CollectorTypeReasonKey.stillUnfolding,
  });

  final CollectorTypeArchetypeId archetypeId;
  final DateTime revealedAt;
  final String signatureHash;
  final CollectorTypeStats stats;

  /// Causal reason from the resolve pass that produced this identity.
  ///
  /// Write path always [healed] so this matches [displayReasonKey] after load/save.
  /// UI must not map archetype → copy; use [CollectorTypeCopy.becauseLineFor].
  final CollectorTypeReasonKey reasonKey;

  CollectorTypeArchetype get archetype =>
      CollectorTypeArchetypes.byId(archetypeId);

  /// Canonical reason for Because copy (heals legacy `stillUnfolding` mismatch).
  ///
  /// Single read API for Hero, Reveal ceremony, Personality Memory, Timeline.
  CollectorTypeReasonKey get displayReasonKey => effectiveReasonKey(
        archetypeId: archetypeId,
        reasonKey: reasonKey,
      );

  /// Returns this identity, or a copy with [displayReasonKey] if healing applied.
  CollectorTypeIdentity healed() {
    final key = displayReasonKey;
    if (key == reasonKey) return this;
    return CollectorTypeIdentity(
      archetypeId: archetypeId,
      revealedAt: revealedAt,
      signatureHash: signatureHash,
      stats: stats,
      reasonKey: key,
    );
  }

  Map<String, dynamic> toJson() => {
        'v': 2,
        'archetypeId': archetypeId.name,
        'revealedAtMs': revealedAt.millisecondsSinceEpoch,
        'signatureHash': signatureHash,
        'stats': stats.toJson(),
        'reasonKey': reasonKey.name,
      };

  factory CollectorTypeIdentity.fromJson(Map<String, dynamic> json) {
    final idName = json['archetypeId'] as String? ?? '';
    final id = CollectorTypeArchetypeIdCodec.fromName(idName);
    final statsRaw = json['stats'];
    final stats = statsRaw is Map<String, dynamic>
        ? CollectorTypeStats.fromJson(statsRaw)
        : const CollectorTypeStats(
            totalOwned: 0,
            totalWishlist: 0,
            trackedSeries: 0,
            completedSeriesCount: 0,
            masterCompleteSeriesCount: 0,
            completionPercent: 0,
            secretOwned: 0,
            secretSlots: 0,
            brandBreakdown: {},
            topSeries: [],
            customSeriesRatio: 0,
          );
    final revealedMs = json['revealedAtMs'] as int? ?? 0;
    return CollectorTypeIdentity(
      archetypeId: id,
      revealedAt: DateTime.fromMillisecondsSinceEpoch(revealedMs),
      signatureHash: json['signatureHash'] as String? ?? '',
      stats: stats,
      reasonKey: CollectorTypeReasonKeyCodec.fromName(
        json['reasonKey'] as String?,
      ),
    ).healed();
  }
}
