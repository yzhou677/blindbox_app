import 'package:blindbox_app/core/theme/app_theme.dart';
import 'package:blindbox_app/features/catalog/application/catalog_bundle_provider.dart';
import 'package:blindbox_app/features/catalog/catalog_seed_loader.dart';
import 'package:blindbox_app/features/collection/application/collection_notifier.dart';
import 'package:blindbox_app/features/collection/data/collection_memory_store.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/collection/insights/application/collector_type_resolver.dart';
import 'package:blindbox_app/features/collection/insights/domain/collector_type_archetype.dart';
import 'package:blindbox_app/features/collection/insights/domain/collector_type_identity.dart';
import 'package:blindbox_app/features/collection/insights/domain/collector_type_stats.dart';
import 'package:blindbox_app/features/collection/insights/presentation/collector_type_copy.dart';
import 'package:blindbox_app/features/collection/insights/widgets/collector_type_reveal_button.dart';
import 'package:blindbox_app/features/collection/insights/widgets/collector_type_reveal_card.dart';
import 'package:blindbox_app/features/collection/insights/widgets/collector_type_stale_insights_overlay.dart';
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
      child: MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: SingleChildScrollView(child: child),
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

  testWidgets('stale collection keeps dashboard visible with de-emphasis',
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

    expect(find.byType(CollectorTypeStaleInsightsOverlay), findsOneWidget);
    expect(find.text(CollectorTypeCopy.revealAgain), findsOneWidget);
    expect(find.byType(CollectorTypeRevealButton), findsOneWidget);
    expect(find.text('The Wanderer'), findsOneWidget);
    expect(find.text(CollectorTypeCopy.statsSectionTitle), findsOneWidget);
    expect(find.text(CollectorTypeCopy.staleInsightsMessage), findsOneWidget);
    expect(
      tester
          .widget<Opacity>(find.byKey(const ValueKey('stale-insights-deemphasis')))
          .opacity,
      collectorTypeStaleInsightsOpacity,
    );
  });
}
