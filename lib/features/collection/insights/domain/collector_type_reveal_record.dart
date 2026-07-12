import 'package:blindbox_app/features/collection/insights/domain/collector_type_archetype.dart';
import 'package:blindbox_app/features/collection/insights/domain/collector_type_identity.dart';
import 'package:blindbox_app/features/collection/insights/domain/collector_type_reason_key.dart';
import 'package:blindbox_app/features/collection/insights/domain/collector_type_reason_resolve.dart';
import 'package:blindbox_app/features/collection/insights/domain/collector_type_resolution.dart';
import 'package:flutter/foundation.dart';

/// Version of the Collector Type resolver contract.
///
/// This is a **schema / policy version**, not an app version. Prefer rare,
/// meaningful bumps (`1.0` → `2.0`) over incremental `1.1` / `1.2` churn.
/// Bump only when history would need to be **re-interpreted** — i.e. when the
/// same shelf snapshot could resolve to a different collector identity or
/// explanation under the new rules.
///
/// **2.0** — Signal ownership freeze: Identity scores from **current shelf**
/// only. Journey memory (`ipSeriesDepth`, `firstSeriesAddedAt`) removed from
/// Curator / Worldbuilder scoring. See scoring signal table on
/// [resolveCollectorType] / `_scoreArchetypes`.
///
/// Display rename Archivist → Worldbuilder is copy/id only (same signals).
///
/// **3.0** — Taxonomy simplify: removed Stylist and Daydream Collector.
/// Daydream → Dreamer. Stylist removed (no successor).
///
/// **4.0** — Worldbuilder authorship rewrite: custom series ratio is primary;
/// notes/covers/photos deepen score only on custom rows (product UI never
/// attaches those to official catalog series). Catalog-only shelves do not
/// qualify.
///
/// **5.0** — Behavior inference: Identity requires defining shelf behavior
/// (ratio / share / density / composition), not isolated evidence counts.
/// Trend / Curator / Hunter / Completionist no longer score from presence
/// alone; soft-capped scale bonuses only after eligibility.
///
/// **5.1** — Evolution gate: `shouldEvolve` compares candidate vs previous
/// identity via margin (+ cooldown-scaled margin) only. Resolution.confidence
/// no longer blocks evolution (it remains on the Resolution for analytics).
///
/// **5.2** — Reveal lifecycle: signature / `needsReveal` answer **When** only.
/// A reveal started while `needsReveal` persists the resolver candidate;
/// `sameSignature` must not Still-override that reinterpretation. `shouldEvolve`
/// (incl. sameSignature) applies only on unchanged-shelf repeated reveals.
///
/// **Bump when** a change can alter Identity or Explainability for the same
/// shelf:
/// - scoring weights
/// - thresholds
/// - hysteresis policy
/// - confidence calculation
/// - tie-break order
/// - archetype qualification / scoring branches
/// - reasonKey generation rules
/// - taxonomy interpretation (e.g. what “Curator” means in scoring)
/// - signal ownership / bounded-context inputs
///
/// **Do NOT bump for:**
/// - copy / text (`becauseLine`, flavor)
/// - UI / layout / Hero / Reveal / Timeline presentation
/// - animation changes
/// - storage or Provider refactors
/// - Flutter-layer performance work
///
/// Stamped onto every [CollectorTypeRevealRecord]. Do not branch on this in
/// Collector Type UI or resolver logic — Timeline / Personality Memory
/// replay past results without re-running a future resolver.
const String kCollectorTypeResolverVersion = '5.2';

/// Append-only resolve snapshot — Personality Memory / Timeline / replay.
///
/// Persist enough of the resolve pass that later Timeline / Personality Memory
/// can answer “why were you The Loyalist then?” without re-running the Resolver.
///
/// Causal copy: [CollectorTypeCopy.becauseLineForRecord] only — never
/// re-resolve or `switch` on archetype for Because text.
///
/// [confidence] and [resolverVersion] are historical metadata only. Do not show
/// them in Collector Type product UI.
@immutable
class CollectorTypeRevealRecord {
  const CollectorTypeRevealRecord({
    required this.archetypeId,
    required this.revealedAt,
    required this.signatureHash,
    required this.reasonKey,
    required this.score,
    required this.confidence,
    this.resolverVersion = kCollectorTypeResolverVersion,
    this.isEvolution = false,
  });

  /// Persisted type at this reveal (may differ from challenger winner on Still).
  final CollectorTypeArchetypeId archetypeId;
  final DateTime revealedAt;
  final String signatureHash;

  /// Healed Because key for [archetypeId] at this reveal.
  final CollectorTypeReasonKey reasonKey;

  /// Score for [archetypeId] on this resolve pass’s scoreboard.
  final double score;

  /// Winner vs runner-up separation for this pass (0–1). Replay only.
  final double confidence;

  /// Which resolver policy produced this snapshot — never reinterpret with a
  /// newer resolver. See [kCollectorTypeResolverVersion].
  final String resolverVersion;

  /// True when the persisted type changed vs the prior identity.
  final bool isEvolution;

  /// Same heal contract as [CollectorTypeIdentity.displayReasonKey].
  CollectorTypeReasonKey get displayReasonKey => effectiveReasonKey(
        archetypeId: archetypeId,
        reasonKey: reasonKey,
      );

  /// Snapshot of one reveal — uses [identity] for what was persisted and
  /// [resolution] for scoreboard numbers from that pass.
  factory CollectorTypeRevealRecord.fromResolvePass({
    required CollectorTypeIdentity identity,
    required CollectorTypeResolution resolution,
    required bool isEvolution,
  }) {
    final id = identity.archetypeId;
    final score = resolution.scores[id] ??
        (resolution.archetypeId == id ? resolution.score : 0.0);
    return CollectorTypeRevealRecord(
      archetypeId: id,
      revealedAt: identity.revealedAt,
      signatureHash: identity.signatureHash,
      reasonKey: identity.displayReasonKey,
      score: score,
      confidence: resolution.confidence,
      resolverVersion: kCollectorTypeResolverVersion,
      isEvolution: isEvolution,
    );
  }

  Map<String, dynamic> toJson() => {
        'v': 2,
        'archetypeId': archetypeId.name,
        'revealedAtMs': revealedAt.millisecondsSinceEpoch,
        'signatureHash': signatureHash,
        'reasonKey': reasonKey.name,
        'score': score,
        'confidence': confidence,
        'resolverVersion': resolverVersion,
        'isEvolution': isEvolution,
      };

  factory CollectorTypeRevealRecord.fromJson(Map<String, dynamic> json) {
    final idName = json['archetypeId'] as String? ?? '';
    final id = CollectorTypeArchetypeIdCodec.fromName(idName);
    final ms = json['revealedAtMs'] as int? ?? 0;
    final raw = CollectorTypeReasonKeyCodec.fromName(
      json['reasonKey'] as String?,
    );
    final version = json['resolverVersion'] as String?;
    return CollectorTypeRevealRecord(
      archetypeId: id,
      revealedAt: DateTime.fromMillisecondsSinceEpoch(ms),
      signatureHash: json['signatureHash'] as String? ?? '',
      reasonKey: effectiveReasonKey(archetypeId: id, reasonKey: raw),
      score: (json['score'] as num?)?.toDouble() ?? 0,
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0,
      // Pre-version records were produced under the 1.0 policy.
      resolverVersion:
          (version != null && version.isNotEmpty) ? version : '1.0',
      isEvolution: json['isEvolution'] as bool? ?? false,
    );
  }
}
