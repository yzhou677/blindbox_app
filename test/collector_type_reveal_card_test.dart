import 'package:blindbox_app/core/theme/app_theme.dart';
import 'package:blindbox_app/features/catalog/application/catalog_bundle_provider.dart';
import 'package:blindbox_app/features/catalog/catalog_bundle.dart';
import 'package:blindbox_app/features/collection/application/collection_notifier.dart';
import 'package:blindbox_app/features/collection/data/collection_memory_store.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/collection/insights/application/collector_type_resolver.dart';
import 'package:blindbox_app/features/collection/insights/domain/collector_type_archetype.dart';
import 'package:blindbox_app/features/collection/insights/domain/collector_type_identity.dart';
import 'package:blindbox_app/features/collection/insights/domain/collector_type_stats.dart';
import 'package:blindbox_app/features/collection/insights/presentation/collection_insights_body.dart';
import 'package:blindbox_app/features/collection/insights/presentation/collector_type_copy.dart';
import 'package:blindbox_app/features/collection/insights/widgets/collector_type_reveal_button.dart';
import 'package:blindbox_app/features/collection/insights/widgets/collector_type_reveal_card.dart';
import 'package:blindbox_app/features/collection/insights/widgets/collector_type_stale_insights_overlay.dart';
import 'package:blindbox_app/features/collection/insights/widgets/insights_archived_scope.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/collection_fixtures.dart';

final class RevealCardTestNotifier extends CollectionNotifier {
  @override
  CollectionSnapshot build() => CollectionSnapshot(
        shelfSeries: [testShelfSeries()],
        figureStates: const {},
      );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    CollectionMemoryStore.instance.resetForTest();
  });

  final emptyCatalog = const CatalogSeedBundle(
    brands: [],
    ips: [],
    series: [],
    figures: [],
  );

  Widget wrap(Widget child, {List<Override> overrides = const []}) {
    return ProviderScope(
      overrides: [
        collectionNotifierProvider.overrideWith(RevealCardTestNotifier.new),
        catalogBundleProvider.overrideWith((ref) async => emptyCatalog),
        ...overrides,
      ],
      child: MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: SingleChildScrollView(child: child),
          ),
        ),
      ),
    );
  }

  testWidgets('idle shows reveal button', (tester) async {
    await tester.pumpWidget(wrap(const CollectorTypeRevealCard()));
    await tester.pump();
    expect(find.text(CollectorTypeCopy.revealButton), findsOneWidget);
  });

  testWidgets('tap reveal shows analyzing then result', (tester) async {
    await tester.pumpWidget(wrap(const CollectorTypeRevealCard()));
    await tester.pump();

    await tester.tap(find.text(CollectorTypeCopy.revealButton));
    await tester.pump();
    expect(find.text(CollectorTypeCopy.analyzingLine), findsOneWidget);

    await tester.pump(const Duration(milliseconds: collectorTypeAnalyzingHoldMs));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text(CollectorTypeCopy.analyzingLine), findsNothing);
    expect(find.byType(CollectorTypeRevealCard), findsOneWidget);
    expect(find.textContaining('The '), findsWidgets);
  });

  testWidgets('cached identity opens dashboard without reveal again CTA',
      (tester) async {
    final revealedAt = DateTime.now().subtract(const Duration(days: 3));
    final snap = CollectionSnapshot(
      shelfSeries: [testShelfSeries()],
      figureStates: const {},
    );
    final signature = computeCollectorTypeSignatureHash(snap);
    await CollectionMemoryStore.instance.saveCollectorType(
      CollectorTypeIdentity(
        archetypeId: CollectorTypeArchetypeId.wanderer,
        revealedAt: revealedAt,
        signatureHash: signature,
        stats: const CollectorTypeStats(
          totalOwned: 1,
          totalWishlist: 0,
          trackedSeries: 1,
          completedSeriesCount: 0,
          masterCompleteSeriesCount: 0,
          completionPercent: 50,
          secretOwned: 0,
          secretSlots: 0,
          brandBreakdown: {'pop_mart': 1},
          topSeries: ['Test Series'],
          customSeriesRatio: 0,
        ),
      ),
    );

    await tester.pumpWidget(wrap(const CollectorTypeRevealCard()));
    await tester.pump();

    expect(find.text('The Wanderer'), findsOneWidget);
    expect(find.textContaining('Updated'), findsOneWidget);
    expect(find.textContaining('3 days ago'), findsOneWidget);
    expect(find.text(CollectorTypeCopy.statsSectionTitle), findsOneWidget);
    expect(find.byType(CollectorTypeRevealButton), findsNothing);
    expect(find.text(CollectorTypeCopy.revealAgain), findsNothing);
  });

  testWidgets('stale reveal snapshot archives; journey stays live',
      (tester) async {
    final revealedAt = DateTime.now().subtract(const Duration(days: 3));
    await CollectionMemoryStore.instance.saveCollectorType(
      CollectorTypeIdentity(
        archetypeId: CollectorTypeArchetypeId.wanderer,
        revealedAt: revealedAt,
        signatureHash: 'stale-signature',
        stats: const CollectorTypeStats(
          totalOwned: 1,
          totalWishlist: 0,
          trackedSeries: 1,
          completedSeriesCount: 0,
          masterCompleteSeriesCount: 0,
          completionPercent: 50,
          secretOwned: 0,
          secretSlots: 0,
          brandBreakdown: {'pop_mart': 1},
          topSeries: ['Test Series'],
          customSeriesRatio: 0,
        ),
      ),
    );

    await tester.pumpWidget(wrap(const CollectionInsightsBody()));
    await tester.pump();

    expect(find.byType(CollectorTypeStaleInsightsOverlay), findsOneWidget);
    expect(find.text(CollectorTypeCopy.revealAgain), findsOneWidget);
    expect(find.text('The Wanderer'), findsOneWidget);
    expect(find.text(CollectorTypeCopy.statsSectionTitle), findsOneWidget);
    expect(find.text(CollectorTypeCopy.journeyTitle), findsOneWidget);

    final bannerY =
        tester.getTopLeft(find.byType(CollectorTypeStaleInsightsOverlay)).dy;
    final typeY = tester.getTopLeft(find.text('The Wanderer')).dy;
    final journeyY =
        tester.getTopLeft(find.text(CollectorTypeCopy.journeyTitle)).dy;
    expect(bannerY < typeY, isTrue);
    expect(typeY < journeyY, isTrue);

    expect(find.byKey(const Key('insights_archived_opacity')), findsOneWidget);
    expect(
      tester
          .widget<Opacity>(find.byKey(const Key('insights_archived_opacity')))
          .opacity,
      collectorTypeStaleInsightsOpacity,
    );
    expect(
      find.byKey(const Key('insights_archived_desaturate')),
      findsOneWidget,
    );

    // Journey sits outside the archived reveal snapshot.
    final archivedBox = tester.getRect(
      find.byKey(const Key('insights_archived_opacity')),
    );
    final journeyBox = tester.getRect(
      find.text(CollectorTypeCopy.journeyTitle),
    );
    expect(journeyBox.top >= archivedBox.bottom - 0.5, isTrue);
  });

  testWidgets('reveal again clears stale banner after analysis completes',
      (tester) async {
    await CollectionMemoryStore.instance.saveCollectorType(
      CollectorTypeIdentity(
        archetypeId: CollectorTypeArchetypeId.wanderer,
        revealedAt: DateTime.now().subtract(const Duration(days: 3)),
        signatureHash: 'stale-signature',
        stats: const CollectorTypeStats(
          totalOwned: 1,
          totalWishlist: 0,
          trackedSeries: 1,
          completedSeriesCount: 0,
          masterCompleteSeriesCount: 0,
          completionPercent: 50,
          secretOwned: 0,
          secretSlots: 0,
          brandBreakdown: {'pop_mart': 1},
          topSeries: ['Test Series'],
          customSeriesRatio: 0,
        ),
      ),
    );

    await tester.pumpWidget(wrap(const CollectionInsightsBody()));
    await tester.pump();

    expect(find.byType(CollectorTypeStaleInsightsOverlay), findsOneWidget);

    await tester.tap(find.text(CollectorTypeCopy.revealAgain));
    await tester.pump();
    expect(find.text(CollectorTypeCopy.analyzingLine), findsOneWidget);

    await tester.pump(const Duration(milliseconds: collectorTypeAnalyzingHoldMs));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(CollectorTypeStaleInsightsOverlay), findsNothing);
    expect(find.text(CollectorTypeCopy.revealAgain), findsNothing);
    expect(find.byKey(const Key('insights_archived_opacity')), findsNothing);
    expect(find.textContaining('Updated'), findsOneWidget);
  });
}
