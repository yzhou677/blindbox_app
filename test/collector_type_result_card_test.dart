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
    revealedAt: DateTime(2026, 5, 1),
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

  testWidgets('renders archetype name and flavor in light theme', (tester) async {
    await pumpCard(tester, AppTheme.light());
    expect(find.text(archetype.displayName), findsOneWidget);
    expect(find.textContaining('Rare pulls'), findsOneWidget);
    expect(find.byIcon(archetype.icon!), findsOneWidget);
  });

  testWidgets('renders archetype name and flavor in dark theme', (tester) async {
    await pumpCard(tester, AppTheme.dark());
    expect(find.text(archetype.displayName), findsOneWidget);
    expect(find.textContaining('Rare pulls'), findsOneWidget);
  });
}
