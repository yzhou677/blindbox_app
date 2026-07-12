import 'package:blindbox_app/features/collection/application/shelf_emotional_interpreter.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/collection/insights/application/collector_type_evolution_gate.dart';
import 'package:blindbox_app/features/collection/insights/application/collector_type_resolver.dart';
import 'package:blindbox_app/features/collection/insights/domain/collector_type_archetype.dart';
import 'package:blindbox_app/features/collection/insights/domain/collector_type_identity.dart';
import 'package:blindbox_app/features/collection/insights/domain/collector_type_reason_key.dart';
import 'package:blindbox_app/features/collection/insights/domain/collector_type_reveal_record.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Audit reachability of [shouldEvolve] across shelves that *should* evolve.
/// Audit only — does not change product code.

ShelfSeries _series({
  required String id,
  required String brand,
  required String ip,
  required int figs,
  int owned = 0,
  bool complete = false,
  bool custom = false,
  List<bool>? secretFlags,
}) {
  final figures = <ShelfFigure>[
    for (var i = 0; i < figs; i++)
      ShelfFigure(
        id: '${id}_$i',
        seriesId: id,
        name: 'F$i',
        rarity: (secretFlags != null &&
                i < secretFlags.length &&
                secretFlags[i])
            ? 'Secret'
            : 'Regular',
        isSecret: secretFlags != null &&
            i < secretFlags.length &&
            secretFlags[i],
      ),
  ];
  return ShelfSeries(
    id: id,
    name: 'Series $id',
    brand: brand,
    ipName: ip,
    figures: figures,
    shelfAccent: const Color(0xFFE4F2EA),
    taxonomyBrandId: brand,
    taxonomyIpId: ip,
    catalogTemplateId: custom ? null : 'catalog_$id',
  );
}

TrackedFigure _owned(String id) =>
    TrackedFigure(figureId: id, state: FigureCollectionState.owned);

TrackedFigure _wish(String id) =>
    TrackedFigure(figureId: id, state: FigureCollectionState.wishlist);

CollectionSnapshot _snap(
  List<ShelfSeries> series, {
  Map<String, TrackedFigure>? states,
}) {
  return CollectionSnapshot(
    shelfSeries: series,
    figureStates: states ?? const {},
  );
}

Map<String, TrackedFigure> _ownAll(ShelfSeries s) => {
      for (final f in s.figures) f.id: _owned(f.id),
    };

Map<String, TrackedFigure> _ownFirst(ShelfSeries s, int n) => {
      for (final f in s.figures.take(n)) f.id: _owned(f.id),
    };

({
  String blocker,
  bool evolved,
  bool sameType,
  bool sameSignature,
  bool resolverChanged,
  bool previousAbsent,
  double previousScore,
  double challengerScore,
  double margin,
  double confidence,
  bool confidenceEnough,
  bool inCooldown,
  double requiredMargin,
  bool marginEnough,
}) _eval({
  required CollectorTypeIdentity previous,
  required CollectionSnapshot nextShelf,
  required DateTime now,
  String previousResolverVersion = kCollectorTypeResolverVersion,
}) {
  final challenger = resolveCollectorType(
    snapshot: nextShelf,
    profile: interpretShelf(nextShelf),
    revealedAt: now,
  );

  final sameType = challenger.archetypeId == previous.archetypeId;
  final sameSignature =
      challenger.signatureHash == previous.signatureHash;
  final resolverChanged =
      previousResolverVersion != kCollectorTypeResolverVersion;
  final previousScore =
      challenger.scores[previous.archetypeId] ?? 0.0;
  final previousAbsent = previousScore <= 0;
  final margin = challenger.score - previousScore;
  final confidence = challenger.confidence;
  final since = now.difference(previous.revealedAt);
  final inCooldown = since < kCollectorTypeEvolutionSoftCooldown;
  final requiredMargin = inCooldown
      ? kCollectorTypeEvolutionScoreMargin +
          kCollectorTypeEvolutionCooldownExtraMargin
      : kCollectorTypeEvolutionScoreMargin;
  final marginEnough = margin >= requiredMargin;

  String blocker = 'none (would evolve)';
  if (sameType) {
    blocker = 'sameType';
  } else if (sameSignature && !resolverChanged && !previousAbsent) {
    blocker = 'sameSignature';
  } else if (nextShelf.shelfSeries.isEmpty && challenger.score <= 0) {
    blocker = 'emptyShelf';
  } else if (margin < kCollectorTypeEvolutionScoreMargin) {
    blocker = 'margin<12 (base)';
  } else if (resolverChanged || previousAbsent) {
    blocker = 'none (reinterpretation path)';
  } else if (inCooldown && margin < requiredMargin) {
    blocker = 'cooldown margin<20';
  }

  final evolved = shouldEvolve(
    previous: previous,
    challenger: challenger,
    snapshot: nextShelf,
    now: now,
    previousResolverVersion: previousResolverVersion,
  );

  return (
    blocker: evolved ? 'none (evolved)' : blocker,
    evolved: evolved,
    sameType: sameType,
    sameSignature: sameSignature,
    resolverChanged: resolverChanged,
    previousAbsent: previousAbsent,
    previousScore: previousScore,
    challengerScore: challenger.score,
    margin: margin,
    confidence: confidence,
    confidenceEnough: true, // 5.1: not a gate
    inCooldown: inCooldown,
    requiredMargin: requiredMargin,
    marginEnough: marginEnough,
  );
}

CollectorTypeIdentity _revealAs(
  CollectionSnapshot shelf,
  DateTime at, {
  CollectorTypeArchetypeId? forceId,
}) {
  final r = resolveCollectorType(
    snapshot: shelf,
    profile: interpretShelf(shelf),
    revealedAt: at,
  );
  return CollectorTypeIdentity(
    archetypeId: forceId ?? r.archetypeId,
    revealedAt: at,
    // Mimic ViewModel persist: signature always current shelf after reveal.
    signatureHash: r.signatureHash,
    stats: r.stats,
    reasonKey: r.reasonKey,
  );
}

void main() {
  test('shouldEvolve reachability audit — 6 natural evolution shelves', () {
    final now = DateTime(2026, 7, 12, 12);
    final t0 = DateTime(2026, 6, 1); // outside cooldown
    final recent = DateTime(2026, 7, 12, 6); // inside cooldown

    final cases = <({
      String name,
      CollectionSnapshot before,
      CollectionSnapshot after,
      DateTime revealedAt,
      CollectorTypeArchetypeId? forcePrevious,
    })>[
      // 1. Loyalist one-IP → multi-brand gallery (should become Curator)
      (
        name: '1. Loyalist Smiski → add two brands (→ Curator)',
        before: _snap([
          _series(id: 'sm1', brand: 'dreams', ip: 'smiski', figs: 4, owned: 2),
          _series(id: 'sm2', brand: 'dreams', ip: 'smiski', figs: 4, owned: 2),
        ], states: {
          'sm1_0': _owned('sm1_0'),
          'sm1_1': _owned('sm1_1'),
          'sm2_0': _owned('sm2_0'),
          'sm2_1': _owned('sm2_1'),
        }),
        after: _snap([
          _series(id: 'sm1', brand: 'dreams', ip: 'smiski', figs: 4),
          _series(id: 'sm2', brand: 'dreams', ip: 'smiski', figs: 4),
          _series(id: 'p1', brand: 'pop_mart', ip: 'hirono', figs: 4),
          _series(id: 't1', brand: 'toptoy', ip: 'nommi', figs: 4),
        ], states: {
          'sm1_0': _owned('sm1_0'),
          'sm1_1': _owned('sm1_1'),
          'sm2_0': _owned('sm2_0'),
          'sm2_1': _owned('sm2_1'),
          'p1_0': _owned('p1_0'),
          't1_0': _owned('t1_0'),
        }),
        revealedAt: t0,
        forcePrevious: null,
      ),
      // 2. Curator incomplete → finish all series (→ Completionist)
      (
        name: '2. Curator incomplete → complete all (→ Completionist)',
        before: () {
          final a = _series(id: 'a', brand: 'pop', ip: 'ip1', figs: 3);
          final b = _series(id: 'b', brand: 'sonny', ip: 'ip2', figs: 3);
          final c = _series(id: 'c', brand: 'top', ip: 'ip3', figs: 3);
          return _snap([a, b, c], states: {
            ..._ownFirst(a, 1),
            ..._ownFirst(b, 1),
            ..._ownFirst(c, 1),
          });
        }(),
        after: () {
          final a = _series(id: 'a', brand: 'pop', ip: 'ip1', figs: 3);
          final b = _series(id: 'b', brand: 'sonny', ip: 'ip2', figs: 3);
          final c = _series(id: 'c', brand: 'top', ip: 'ip3', figs: 3);
          return _snap([a, b, c], states: {
            ..._ownAll(a),
            ..._ownAll(b),
            ..._ownAll(c),
          });
        }(),
        revealedAt: t0,
        forcePrevious: null,
      ),
      // 3. Dreamer wishlist → mostly own (should leave Dreamer)
      (
        name: '3. Dreamer wishlist-heavy → own figures (leave Dreamer)',
        before: () {
          final s = _series(id: 'd1', brand: 'pop', ip: 'labubu', figs: 6);
          return _snap([s], states: {
            for (final f in s.figures) f.id: _wish(f.id),
          });
        }(),
        after: () {
          final s = _series(id: 'd1', brand: 'pop', ip: 'labubu', figs: 6);
          final s2 = _series(id: 'd2', brand: 'pop', ip: 'labubu', figs: 4);
          return _snap([s, s2], states: {
            ..._ownAll(s),
            ..._ownAll(s2),
          });
        }(),
        revealedAt: t0,
        forcePrevious: null,
      ),
      // 4. Minimalist tiny → large diverse shelf
      (
        name: '4. Minimalist tiny finished → large diverse (→ Curator/Complete)',
        before: () {
          final s = _series(id: 'm1', brand: 'pop', ip: 'ip1', figs: 3);
          final s2 = _series(id: 'm2', brand: 'pop', ip: 'ip1', figs: 3);
          return _snap([s, s2], states: {..._ownAll(s), ..._ownAll(s2)});
        }(),
        after: () {
          final series = [
            for (var i = 0; i < 6; i++)
              _series(
                id: 'x$i',
                brand: i.isEven ? 'pop' : 'sonny',
                ip: 'ip$i',
                figs: 4,
              ),
          ];
          return _snap(series, states: {
            for (final s in series) ..._ownFirst(s, 1),
          });
        }(),
        revealedAt: t0,
        forcePrevious: null,
      ),
      // 5. Hunter secrets → finish everything (→ Completionist), outside cooldown
      (
        name: '5. Hunter secrets → complete shelf (→ Completionist)',
        before: () {
          final s = _series(
            id: 'h1',
            brand: 'pop',
            ip: 'monsters',
            figs: 6,
            secretFlags: [true, true, true, false, false, false],
          );
          return _snap([s], states: {
            'h1_0': _owned('h1_0'),
            'h1_1': _owned('h1_1'),
            'h1_2': _owned('h1_2'),
          });
        }(),
        after: () {
          final s = _series(
            id: 'h1',
            brand: 'pop',
            ip: 'monsters',
            figs: 6,
            secretFlags: [true, true, true, false, false, false],
          );
          final s2 = _series(id: 'h2', brand: 'pop', ip: 'monsters', figs: 4);
          return _snap([s, s2], states: {..._ownAll(s), ..._ownAll(s2)});
        }(),
        revealedAt: t0,
        forcePrevious: null,
      ),
      // 6. Same growth as #1 but reveal was 6h ago (cooldown)
      (
        name: '6. Same as #1 but inside 24h cooldown',
        before: _snap([
          _series(id: 'sm1', brand: 'dreams', ip: 'smiski', figs: 4),
          _series(id: 'sm2', brand: 'dreams', ip: 'smiski', figs: 4),
        ], states: {
          'sm1_0': _owned('sm1_0'),
          'sm1_1': _owned('sm1_1'),
          'sm2_0': _owned('sm2_0'),
          'sm2_1': _owned('sm2_1'),
        }),
        after: _snap([
          _series(id: 'sm1', brand: 'dreams', ip: 'smiski', figs: 4),
          _series(id: 'sm2', brand: 'dreams', ip: 'smiski', figs: 4),
          _series(id: 'p1', brand: 'pop_mart', ip: 'hirono', figs: 4),
          _series(id: 't1', brand: 'toptoy', ip: 'nommi', figs: 4),
        ], states: {
          'sm1_0': _owned('sm1_0'),
          'sm1_1': _owned('sm1_1'),
          'sm2_0': _owned('sm2_0'),
          'sm2_1': _owned('sm2_1'),
          'p1_0': _owned('p1_0'),
          't1_0': _owned('t1_0'),
        }),
        revealedAt: recent,
        forcePrevious: null,
      ),
    ];

    final blockerCounts = <String, int>{};
    final buf = StringBuffer()..writeln('=== shouldEvolve REACHABILITY AUDIT ===\n');
    var evolveCount = 0;

    for (final c in cases) {
      final prevResolve = resolveCollectorType(
        snapshot: c.before,
        profile: interpretShelf(c.before),
        revealedAt: c.revealedAt,
      );
      final previous = _revealAs(
        c.before,
        c.revealedAt,
        forceId: c.forcePrevious,
      );
      final nextResolve = resolveCollectorType(
        snapshot: c.after,
        profile: interpretShelf(c.after),
        revealedAt: now,
      );
      final g = _eval(
        previous: previous,
        nextShelf: c.after,
        now: now,
      );

      if (g.evolved) evolveCount++;
      blockerCounts[g.blocker] = (blockerCounts[g.blocker] ?? 0) + 1;

      buf
        ..writeln('--- ${c.name} ---')
        ..writeln('Previous revealed: ${previous.archetypeId.name} '
            '(first-resolve was ${prevResolve.archetypeId.name})')
        ..writeln('Current winner: ${nextResolve.archetypeId.name} '
            'score=${nextResolve.score.toStringAsFixed(1)}')
        ..writeln('sameType=${g.sameType}')
        ..writeln('sameSignature=${g.sameSignature}')
        ..writeln('resolverVersion: prev=$kCollectorTypeResolverVersion '
            'current=$kCollectorTypeResolverVersion '
            'changed=${g.resolverChanged}')
        ..writeln('previousScoreOnBoard=${g.previousScore.toStringAsFixed(1)} '
            'absent=${g.previousAbsent}')
        ..writeln('challengerScore=${g.challengerScore.toStringAsFixed(1)}')
        ..writeln('margin=${g.margin.toStringAsFixed(1)} '
            '(need >= ${g.requiredMargin}; base12 / cooldown20)')
        ..writeln('confidence=${g.confidence.toStringAsFixed(3)} '
            '(informational; not a 5.1 gate) '
            'enough=${g.confidenceEnough}')
        ..writeln('inCooldown=${g.inCooldown}')
        ..writeln('BLOCKER: ${g.blocker}')
        ..writeln('shouldEvolve=${g.evolved}')
        ..writeln();
    }

    buf
      ..writeln('=== SUMMARY ===')
      ..writeln('evolved $evolveCount / ${cases.length}')
      ..writeln('blocker frequency:');
    for (final e in blockerCounts.entries) {
      buf.writeln('  ${e.key}: ${e.value}');
    }

    // Extra: after Still refresh, signature matches live — then grow shelf.
    // Simulates: first reveal, Still on second attempt stamps new signature,
    // third reveal after more adds.
    final first = _snap([
      _series(id: 'a', brand: 'dreams', ip: 'smiski', figs: 3),
    ], states: {
      'a_0': _owned('a_0'),
    });
    final mid = _snap([
      _series(id: 'a', brand: 'dreams', ip: 'smiski', figs: 3),
      _series(id: 'b', brand: 'pop', ip: 'hirono', figs: 3),
    ], states: {
      'a_0': _owned('a_0'),
      'b_0': _owned('b_0'),
    });
    final late = _snap([
      _series(id: 'a', brand: 'dreams', ip: 'smiski', figs: 3),
      _series(id: 'b', brand: 'pop', ip: 'hirono', figs: 3),
      _series(id: 'c', brand: 'toptoy', ip: 'nommi', figs: 3),
      _series(id: 'd', brand: 'sonny', ip: 'angel', figs: 3),
    ], states: {
      'a_0': _owned('a_0'),
      'b_0': _owned('b_0'),
      'c_0': _owned('c_0'),
      'd_0': _owned('d_0'),
    });

    // Mimic Still: keep first title, stamp mid signature (ViewModel Still path).
    final firstId = resolveCollectorType(
      snapshot: first,
      profile: interpretShelf(first),
      revealedAt: t0,
    ).archetypeId;
    final midRes = resolveCollectorType(
      snapshot: mid,
      profile: interpretShelf(mid),
      revealedAt: now,
    );
    final stillStamped = CollectorTypeIdentity(
      archetypeId: firstId,
      revealedAt: now.subtract(const Duration(hours: 2)),
      signatureHash: midRes.signatureHash, // Still refreshed signature
      stats: midRes.stats,
      reasonKey: CollectorTypeReasonKey.dominantUniverse,
    );
    final afterStill = _eval(
      previous: stillStamped,
      nextShelf: late,
      now: now,
    );
    buf
      ..writeln('--- EXTRA: Still stamped mid signature, then grew again ---')
      ..writeln('Previous (Still-kept): ${stillStamped.archetypeId.name}')
      ..writeln('Current winner: ${resolveCollectorType(snapshot: late, profile: interpretShelf(late), revealedAt: now).archetypeId.name}')
      ..writeln('sameSignature=${afterStill.sameSignature}')
      ..writeln('confidence=${afterStill.confidence.toStringAsFixed(3)}')
      ..writeln('margin=${afterStill.margin.toStringAsFixed(1)}')
      ..writeln('BLOCKER: ${afterStill.blocker}')
      ..writeln('shouldEvolve=${afterStill.evolved}');

    blockerCounts[afterStill.blocker] =
        (blockerCounts[afterStill.blocker] ?? 0) + 1;
    if (afterStill.evolved) evolveCount++;

    // ignore: avoid_print
    print(buf.toString());

    // Audit assertion: document how rare evolution is (not requiring fix here).
    expect(cases.length, greaterThanOrEqualTo(5));
  });
}
