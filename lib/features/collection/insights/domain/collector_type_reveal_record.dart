import 'package:blindbox_app/features/collection/insights/domain/collector_type_archetype.dart';
import 'package:flutter/foundation.dart';

/// Dormant Personality Memory interface — append-only reveal log.
///
/// Collector Type 1.0 does not surface Timeline / Streak / Collector Since.
/// Persist records so v2 can grow without migrating the reveal contract again.
@immutable
class CollectorTypeRevealRecord {
  const CollectorTypeRevealRecord({
    required this.archetypeId,
    required this.revealedAt,
    required this.signatureHash,
  });

  final CollectorTypeArchetypeId archetypeId;
  final DateTime revealedAt;
  final String signatureHash;

  Map<String, dynamic> toJson() => {
        'archetypeId': archetypeId.name,
        'revealedAtMs': revealedAt.millisecondsSinceEpoch,
        'signatureHash': signatureHash,
      };

  factory CollectorTypeRevealRecord.fromJson(Map<String, dynamic> json) {
    final idName = json['archetypeId'] as String? ?? '';
    final id = CollectorTypeArchetypeId.values.asNameMap()[idName] ??
        CollectorTypeArchetypeId.wanderer;
    final ms = json['revealedAtMs'] as int? ?? 0;
    return CollectorTypeRevealRecord(
      archetypeId: id,
      revealedAt: DateTime.fromMillisecondsSinceEpoch(ms),
      signatureHash: json['signatureHash'] as String? ?? '',
    );
  }
}
