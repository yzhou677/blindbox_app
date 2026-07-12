import 'package:blindbox_app/core/theme/app_theme.dart';
import 'package:blindbox_app/features/collection/insights/domain/collector_type_archetype.dart';
import 'package:blindbox_app/features/collection/insights/domain/collector_type_archetypes.dart';
import 'package:blindbox_app/features/collection/insights/domain/collector_type_identity.dart';
import 'package:blindbox_app/features/collection/insights/domain/collector_type_stats.dart';
import 'package:blindbox_app/features/collection/insights/widgets/collector_type_result_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

CollectorTypeIdentity _sampleIdentity() {
  return CollectorTypeIdentity(
    archetypeId: CollectorTypeArchetypeId.hunter,
    revealedAt: DateTime(2026, 6, 1),
    signatureHash: 'hash',
    stats: const CollectorTypeStats(
      totalOwned: 3,
      totalWishlist: 0,
      trackedSeries: 1,
      completionPercent: 50,
      secretOwned: 2,
      secretSlots: 3,
      brandBreakdown: {},
      topSeries: [],
      customSeriesRatio: 0,
    ),
  );
}

void main() {
  final archetype = CollectorTypeArchetypes.hunter;

  Future<void> pumpCard(WidgetTester tester, ThemeData theme) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Scaffold(
          body: CollectorTypeResultCard(identity: _sampleIdentity()),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('renders archetype name; flavor behind Why this type', (
    tester,
  ) async {
    await pumpCard(tester, AppTheme.light());
    expect(find.text(archetype.displayName), findsOneWidget);
    expect(find.text('Why this type'), findsOneWidget);
    expect(find.textContaining('Secret Figures'), findsNothing);

    await tester.tap(find.text('Why this type'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Secret Figures'), findsOneWidget);
    expect(
      find.byKey(const Key('collector_type_mascot_hunter')),
      findsOneWidget,
    );
  });

  testWidgets('renders archetype name in dark theme', (tester) async {
    await pumpCard(tester, AppTheme.dark());
    expect(find.text(archetype.displayName), findsOneWidget);
    expect(find.text('Why this type'), findsOneWidget);
  });

  testWidgets('renders Because line from reasonKey without truncation stack', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: CollectorTypeResultCard(
            identity: _sampleIdentity(),
            becauseLine:
                'Because Secret Figures keep drawing your focus.',
          ),
        ),
      ),
    );
    await tester.pump();

    expect(
      find.text('Because Secret Figures keep drawing your focus.'),
      findsOneWidget,
    );
  });

  testWidgets('helper line expands under Why this type', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: CollectorTypeResultCard(
            identity: _sampleIdentity(),
            helperLine:
                'While your current shelf is focused around a few favorites, your collecting journey has explored many different worlds.',
            updatedAtNow: DateTime(2026, 6, 4),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(
      find.textContaining(
        'your collecting journey has explored many different worlds',
      ),
      findsNothing,
    );
    await tester.tap(find.text('Why this type'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining(
        'your collecting journey has explored many different worlds',
      ),
      findsOneWidget,
    );
    expect(find.text('Updated 3 days ago'), findsOneWidget);
  });

  testWidgets('shows reveal again in dashboard footer when requested', (
    tester,
  ) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: CollectorTypeResultCard(
            identity: _sampleIdentity(),
            showRevealAgain: true,
            onRevealAgain: () => tapped = true,
            updatedAtNow: DateTime(2026, 6, 4),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Updated 3 days ago'), findsOneWidget);
    await tester.tap(find.text('Reveal again'));
    await tester.pump();
    expect(tapped, isTrue);
  });
}
