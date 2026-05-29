import 'package:blindbox_app/core/theme/app_theme.dart';
import 'package:blindbox_app/features/collection/insights/application/collector_journey_summary.dart';
import 'package:blindbox_app/features/collection/insights/application/collector_type_providers.dart';
import 'package:blindbox_app/features/collection/insights/widgets/collector_journey_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows IP and top-IP journey metrics without series total', (
    tester,
  ) async {
    final summary = CollectorJourneySummary(
      ipUniversesExplored: 16,
      seriesExploredOverTime: 32,
      topIps: const [
        CollectorJourneyTopIp(id: 'smiski', label: 'Smiski', seriesCount: 8),
        CollectorJourneyTopIp(id: 'dora', label: 'Dora', seriesCount: 3),
      ],
      journeyAgeLabel: '2 years ago',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          collectorJourneySummaryProvider.overrideWithValue(summary),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(body: CollectorJourneyCard()),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('IPs explored over time'), findsOneWidget);
    expect(find.text('16'), findsOneWidget);
    expect(find.text('Series explored over time'), findsNothing);
    expect(find.text('32'), findsNothing);
    expect(find.text('Most explored IPs'), findsOneWidget);
    expect(find.text('Smiski'), findsOneWidget);
    expect(find.text('Dora'), findsOneWidget);
    expect(find.textContaining('8 series'), findsNothing);
    expect(find.text('Journey began'), findsOneWidget);
    expect(find.text('2 years ago'), findsOneWidget);
  });
}
