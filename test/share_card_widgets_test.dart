import 'package:blindbox_app/features/collection/application/share_payload_builders/collector_type_share_payload_builder.dart';
import 'package:blindbox_app/features/collection/insights/domain/collector_type_archetype.dart';
import 'package:blindbox_app/features/collection/insights/domain/collector_type_identity.dart';
import 'package:blindbox_app/features/collection/insights/domain/collector_type_reason_key.dart';
import 'package:blindbox_app/features/collection/insights/domain/collector_type_stats.dart';
import 'package:blindbox_app/features/sharing/domain/share_card_payloads.dart';
import 'package:blindbox_app/features/sharing/presentation/widgets/shelfy_collector_cards.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _stats = CollectorTypeStats(
  totalOwned: 26,
  totalWishlist: 0,
  trackedSeries: 8,
  completedSeriesCount: 4,
  masterCompleteSeriesCount: 1,
  masterEligibleSeriesCount: 3,
  completionPercent: 68,
  secretOwned: 1,
  secretSlots: 3,
  brandBreakdown: {},
  topSeries: [],
  customSeriesRatio: 0,
);

const _assetImage = ShareCardImageRef(
  kind: ShareCardImageKind.asset,
  value: 'assets/images/app_icon.png',
);

void main() {
  Widget wrap(Widget child) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: kShelfyShareCardLogicalSize.width,
            height: kShelfyShareCardLogicalSize.height,
            child: child,
          ),
        ),
      ),
    );
  }

  testWidgets('Collector Type card lays out without exceptions', (
    tester,
  ) async {
    final payload = buildCollectorTypeSharePayload(
      CollectorTypeIdentity(
        archetypeId: CollectorTypeArchetypeId.completionist,
        revealedAt: DateTime(2026),
        signatureHash: 'test',
        stats: _stats,
        reasonKey: CollectorTypeReasonKey.deepCompletion,
      ),
    );

    await tester.pumpWidget(wrap(CollectorTypeShareCard(payload: payload!)));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('THE COMPLETIONIST'), findsOneWidget);
  });

  testWidgets('Master Complete card lays out without exceptions', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        const MasterCompleteShareCard(
          payload: MasterCompleteSharePayload(
            label: 'SHELFY MASTER CARD · MASTER',
            seriesName: 'EXCITING MACARON',
            image: _assetImage,
            metadata: 'REGULAR 12/12 · SECRET 1/1',
            regularOwned: 12,
            regularTotal: 12,
            secretOwned: 1,
            secretTotal: 1,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('THE CHASE'), findsOneWidget);
    expect(find.text('IS COMPLETE'), findsOneWidget);
    expect(find.text('Every Regular.     Every Secret.'), findsOneWidget);
    for (final speculative in [
      'finally',
      'after a long search',
      'after years',
      'at last',
      'hard-earned',
      'lucky enough',
      'never gave up',
    ]) {
      expect(
        find.textContaining(speculative, findRichText: true),
        findsNothing,
      );
    }
  });

  testWidgets('Shelf card lays out without exceptions', (tester) async {
    await tester.pumpWidget(
      wrap(
        ShelfShareCard(
          payload: ShelfSharePayload(
            label: 'SHELFY SHELF CARD · CURRENT',
            collectorTypeName: 'The Completionist',
            ownedFigureCount: 42,
            trackedSeriesCount: 8,
            completedSeriesCount: 4,
            masterCompleteSeriesCount: 2,
            overallRegularProgress: 68,
            generatedAt: DateTime(2026),
            featuredSeries: [
              for (var i = 0; i < 6; i++)
                ShelfShareSeriesItem(
                  seriesId: 's$i',
                  seriesName: 'Series $i',
                  ipName: 'Shelfy',
                  image: _assetImage,
                  regularProgress: i == 0 ? 1 : 0.68,
                  isCompleted: i == 0,
                  isMasterComplete: i == 0,
                ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.textContaining('OWNED 42'), findsOneWidget);
  });
}
