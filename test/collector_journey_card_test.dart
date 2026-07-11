import 'package:blindbox_app/core/theme/app_theme.dart';
import 'package:blindbox_app/features/collection/insights/application/collector_journey_summary.dart';
import 'package:blindbox_app/features/collection/insights/application/collector_type_providers.dart';
import 'package:blindbox_app/features/collection/insights/presentation/collector_type_copy.dart';
import 'package:blindbox_app/features/collection/insights/widgets/collector_journey_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows started and explored story beats without favorite chips', (
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

    expect(find.text(CollectorTypeCopy.journeyTitle), findsOneWidget);
    expect(find.text(CollectorTypeCopy.journeySubtitle), findsOneWidget);
    expect(find.text(CollectorTypeCopy.journeyStartedLabel), findsOneWidget);
    expect(find.text('2 years ago'), findsOneWidget);
    expect(find.text(CollectorTypeCopy.journeyExploredLabel), findsOneWidget);
    expect(find.text('16'), findsOneWidget);
    expect(find.text('IP universes'), findsOneWidget);
    expect(find.text('Series explored over time'), findsNothing);
    expect(find.text('32'), findsNothing);
    expect(
      find.text(CollectorTypeCopy.journeyFavoriteUniversesTitle),
      findsNothing,
    );
    expect(find.text('Smiski'), findsNothing);
    expect(find.text('Dora'), findsNothing);
    expect(find.textContaining('8 series'), findsNothing);
  });
}
