import 'package:blindbox_app/core/theme/app_theme.dart';
import 'package:blindbox_app/core/theme/collectible_motion.dart';
import 'package:blindbox_app/features/collection/insights/domain/collector_type_archetype.dart';
import 'package:blindbox_app/features/collection/insights/domain/collector_type_identity.dart';
import 'package:blindbox_app/features/collection/insights/domain/collector_type_reason_key.dart';
import 'package:blindbox_app/features/collection/insights/domain/collector_type_stats.dart';
import 'package:blindbox_app/features/collection/insights/presentation/collector_type_copy.dart';
import 'package:blindbox_app/features/collection/insights/widgets/collector_type_reveal_ceremony_motion.dart';
import 'package:blindbox_app/features/collection/insights/widgets/collector_type_reveal_ceremony_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

CollectorTypeIdentity _identity(
  CollectorTypeArchetypeId id, {
  CollectorTypeReasonKey? reasonKey,
}) {
  return CollectorTypeIdentity(
    archetypeId: id,
    revealedAt: DateTime(2026, 7, 1),
    signatureHash: 'sig',
    stats: const CollectorTypeStats(
      totalOwned: 2,
      totalWishlist: 0,
      trackedSeries: 1,
      completedSeriesCount: 0,
      masterCompleteSeriesCount: 0,
      masterEligibleSeriesCount: 0,
      completionPercent: 40,
      secretOwned: 0,
      secretSlots: 0,
      brandBreakdown: {},
      topSeries: [],
      customSeriesRatio: 0,
    ),
    reasonKey: reasonKey ??
        (id == CollectorTypeArchetypeId.loyalist
            ? CollectorTypeReasonKey.dominantUniverse
            : CollectorTypeReasonKey.manySecrets),
  );
}

void main() {
  testWidgets('hero mascot and title share one opacity beat', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: CollectorTypeRevealCeremonyOverlay(
          identity: _identity(CollectorTypeArchetypeId.hunter),
          isFirstReveal: true,
          onFinished: () {},
        ),
      ),
    );

    await tester.pump();
    // Mid-hero entrance ??title should already be visible with the mascot.
    await tester.pump(
      CollectibleMotion.collectorTypeRevealCeremonyFirst * 0.28,
    );

    expect(find.text('The Hunter'), findsOneWidget);
    expect(
      find.text(CollectorTypeCopy.becauseLineFor(
        _identity(CollectorTypeArchetypeId.hunter),
      )),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('collector_type_reveal_ceremony_backdrop')),
      findsOneWidget,
    );
    expect(
      CollectorTypeRevealCeremonyTiming.cta(0.28, first: true),
      lessThan(0.05),
    );
    expect(
      CollectorTypeRevealCeremonyTiming.hero(0.28, first: true),
      greaterThan(0.4),
    );
  });

  testWidgets('Continue appears after hero pause and stays before dismiss', (
    tester,
  ) async {
    var finished = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: CollectorTypeRevealCeremonyOverlay(
          identity: _identity(CollectorTypeArchetypeId.loyalist),
          isFirstReveal: false,
          onFinished: () => finished = true,
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));

    expect(
      find.text(CollectorTypeCopy.revealCeremonyEvolvedIntro),
      findsOneWidget,
    );

    // Hero settled, still in absorb pause ??no meaningful Continue yet.
    final midPause = CollectibleMotion.collectorTypeRevealCeremonyChange * 0.45;
    await tester.pump(midPause);
    expect(
      CollectorTypeRevealCeremonyTiming.heroSettled(0.45, first: false),
      isTrue,
    );
    expect(
      CollectorTypeRevealCeremonyTiming.cta(0.45, first: false),
      lessThan(0.05),
    );
    expect(finished, isFalse);

    // After CTA fade-in.
    await tester.pump(
      CollectibleMotion.collectorTypeRevealCeremonyChange * 0.25,
    );
    expect(find.text(CollectorTypeCopy.revealCeremonyContinue), findsOneWidget);
    expect(finished, isFalse);

    // Dwell remains ??still not auto-dismissed immediately after Continue.
    await tester.pump(const Duration(milliseconds: 400));
    expect(finished, isFalse);

    // Finish only after the remaining dwell + completion.
    await tester.pumpAndSettle(
      CollectibleMotion.collectorTypeRevealCeremonyChange,
    );
    expect(finished, isTrue);
  });

  testWidgets('ceremony Because matches Hero via becauseLineFor', (
    tester,
  ) async {
    final identity = _identity(
      CollectorTypeArchetypeId.loyalist,
      reasonKey: CollectorTypeReasonKey.stillUnfolding,
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: CollectorTypeRevealCeremonyOverlay(
          identity: identity,
          isFirstReveal: true,
          onFinished: () {},
        ),
      ),
    );
    await tester.pump();
    await tester.pump(
      CollectibleMotion.collectorTypeRevealCeremonyFirst * 0.28,
    );

    expect(
      find.text('Because your shelf keeps returning to the same universe.'),
      findsOneWidget,
    );
    expect(
      CollectorTypeCopy.becauseLineFor(identity),
      'Because your shelf keeps returning to the same universe.',
    );
  });

  testWidgets('disableAnimations finishes ceremony immediately', (tester) async {
    var finished = false;
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: MaterialApp(
          theme: AppTheme.light(),
          home: CollectorTypeRevealCeremonyOverlay(
            identity: _identity(CollectorTypeArchetypeId.wanderer),
            isFirstReveal: true,
            onFinished: () => finished = true,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(finished, isTrue);
  });
}
