import 'package:blindbox_app/core/theme/collectible_tokens.dart';
import 'package:blindbox_app/features/collection/presentation/collection_summary_editorial.dart';
import 'package:blindbox_app/features/collection/widgets/collection_summary_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('summary shows figure and series metric labels', (tester) async {
    tester.view.physicalSize = const Size(390, 500);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    const stats = CollectionAggregateStats(
      inCollection: 11,
      wantListCount: 0,
      completedSeriesCount: 3,
      masterCompleteSeriesCount: 1,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          extensions: [CollectibleTokens.forBrightness(Brightness.light)],
        ),
        home: Scaffold(
          body: CollectionSummarySection(
            stats: stats,
            shelfMoodLine: 'Your collection is quietly taking shape.',
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text(CollectionSummaryLabels.figures), findsOneWidget);
    expect(find.text(CollectionSummaryLabels.wishlist), findsOneWidget);
    expect(find.text(CollectionSummaryLabels.seriesComplete), findsOneWidget);
    expect(find.text(CollectionSummaryLabels.masterComplete), findsOneWidget);
    expect(find.text('In collection'), findsNothing);
    expect(find.text('Master'), findsNothing);
  });
}
