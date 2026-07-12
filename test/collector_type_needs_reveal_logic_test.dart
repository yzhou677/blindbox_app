import 'package:blindbox_app/features/collection/insights/application/collector_type_needs_reveal.dart';
import 'package:blindbox_app/features/collection/insights/domain/collector_type_archetype.dart';
import 'package:blindbox_app/features/collection/insights/domain/collector_type_reason_key.dart';
import 'package:blindbox_app/features/collection/insights/domain/collector_type_resolution.dart';
import 'package:blindbox_app/features/collection/insights/domain/collector_type_stats.dart';
import 'package:flutter_test/flutter_test.dart';

CollectorTypeResolution _candidate({
  required CollectorTypeArchetypeId id,
  required String signature,
}) {
  return CollectorTypeResolution(
    archetypeId: id,
    score: 50,
    confidence: 0.8,
    reasonKey: CollectorTypeReasonKey.dominantUniverse,
    signatureHash: signature,
    stats: const CollectorTypeStats(
      totalOwned: 1,
      totalWishlist: 0,
      trackedSeries: 1,
      completionPercent: 10,
      secretOwned: 0,
      secretSlots: 0,
      brandBreakdown: {},
      topSeries: [],
      customSeriesRatio: 0,
    ),
    scores: {for (final a in CollectorTypeArchetypeId.values) a: 0.0},
  );
}

void main() {
  test('false when nothing revealed', () {
    expect(
      computeCollectorTypeNeedsReveal(
        hasRevealed: false,
        persistedSignatureHash: null,
        persistedResolverVersion: null,
        liveCandidate: _candidate(
          id: CollectorTypeArchetypeId.loyalist,
          signature: 'sig',
        ),
        currentResolverVersion: '5.0',
      ),
      isFalse,
    );
  });

  test('true when resolverVersion differs', () {
    expect(
      computeCollectorTypeNeedsReveal(
        hasRevealed: true,
        persistedSignatureHash: 'sig',
        persistedResolverVersion: '4.0',
        liveCandidate: _candidate(
          id: CollectorTypeArchetypeId.loyalist,
          signature: 'sig',
        ),
        currentResolverVersion: '5.0',
      ),
      isTrue,
    );
  });

  test('true when persisted resolverVersion missing (legacy reveal)', () {
    expect(
      computeCollectorTypeNeedsReveal(
        hasRevealed: true,
        persistedSignatureHash: 'sig',
        persistedResolverVersion: null,
        liveCandidate: _candidate(
          id: CollectorTypeArchetypeId.loyalist,
          signature: 'sig',
        ),
        currentResolverVersion: '5.0',
      ),
      isTrue,
    );
  });

  test('true when signature drifted', () {
    expect(
      computeCollectorTypeNeedsReveal(
        hasRevealed: true,
        persistedSignatureHash: 'old',
        persistedResolverVersion: '5.0',
        liveCandidate: _candidate(
          id: CollectorTypeArchetypeId.loyalist,
          signature: 'new',
        ),
        currentResolverVersion: '5.0',
      ),
      isTrue,
    );
  });

  test(
    'false after Still: same signature+version even if candidate archetype differs',
    () {
      // shouldEvolve Still-keeps Loyalist while live winner is Curator.
      // That must NOT keep needsReveal true (infinite Reveal-again loop).
      expect(
        computeCollectorTypeNeedsReveal(
          hasRevealed: true,
          persistedSignatureHash: 'sig',
          persistedResolverVersion: '5.0',
          liveCandidate: _candidate(
            id: CollectorTypeArchetypeId.curator,
            signature: 'sig',
          ),
          currentResolverVersion: '5.0',
        ),
        isFalse,
      );
    },
  );

  test('false when signature and version match', () {
    expect(
      computeCollectorTypeNeedsReveal(
        hasRevealed: true,
        persistedSignatureHash: 'sig',
        persistedResolverVersion: '5.0',
        liveCandidate: _candidate(
          id: CollectorTypeArchetypeId.loyalist,
          signature: 'sig',
        ),
        currentResolverVersion: '5.0',
      ),
      isFalse,
    );
  });
}
