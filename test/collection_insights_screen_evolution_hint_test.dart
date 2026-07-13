import 'package:blindbox_app/core/theme/app_theme.dart';
import 'package:blindbox_app/features/catalog/application/catalog_bundle_provider.dart';
import 'package:blindbox_app/features/catalog/catalog_bundle.dart';
import 'package:blindbox_app/features/collection/application/collection_notifier.dart';
import 'package:blindbox_app/features/collection/data/collection_memory_store.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/collection/insights/application/collector_type_providers.dart';
import 'package:blindbox_app/features/collection/insights/domain/collector_type_archetype.dart';
import 'package:blindbox_app/features/collection/insights/domain/collector_type_identity.dart';
import 'package:blindbox_app/features/collection/insights/domain/collector_type_stats.dart';
import 'package:blindbox_app/features/collection/insights/presentation/collector_type_copy.dart';
import 'package:blindbox_app/features/collection/insights/presentation/collection_insights_screen.dart';
import 'package:blindbox_app/features/collection/insights/widgets/collector_type_stale_insights_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/collection_fixtures.dart';

final class InsightsHintTestNotifier extends CollectionNotifier {
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

  Future<void> pumpScreen(
    WidgetTester tester, {
    required bool showHint,
    bool needsReveal = false,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          collectionNotifierProvider.overrideWith(InsightsHintTestNotifier.new),
          collectorTypeEvolutionHintProvider.overrideWith((ref) => showHint),
          if (needsReveal)
            collectorTypeNeedsRevealProvider.overrideWith((ref) => true),
          catalogBundleProvider.overrideWith(
            (ref) async => const CatalogSeedBundle(
              brands: [],
              ips: [],
              series: [],
              figures: [],
            ),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const CollectionInsightsScreen(),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('shows evolution hint when provider is true', (tester) async {
    await pumpScreen(tester, showHint: true);
    expect(find.text(CollectorTypeCopy.evolutionHint), findsOneWidget);
  });

  testWidgets('evolution hint banner is informational only', (tester) async {
    await pumpScreen(tester, showHint: true);

    expect(find.text(CollectorTypeCopy.analyzingLine), findsNothing);
    await tester.tap(find.text(CollectorTypeCopy.evolutionHint));
    await tester.pump();
    expect(find.text(CollectorTypeCopy.analyzingLine), findsNothing);
  });

  testWidgets('stale collection shows compact stale card alongside evolution hint',
      (tester) async {
    await CollectionMemoryStore.instance.saveCollectorType(
      CollectorTypeIdentity(
        archetypeId: CollectorTypeArchetypeId.wanderer,
        revealedAt: DateTime.now().subtract(const Duration(days: 1)),
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

    await pumpScreen(tester, showHint: true, needsReveal: true);

    expect(find.text(CollectorTypeCopy.evolutionHint), findsOneWidget);
    expect(find.byType(CollectorTypeStaleInsightsOverlay), findsOneWidget);
    expect(find.text(CollectorTypeCopy.staleInsightsMessageCompact), findsOneWidget);
    expect(find.text(CollectorTypeCopy.staleInsightsMessage), findsNothing);
    expect(find.text(CollectorTypeCopy.revealAgain), findsOneWidget);
    expect(find.text('The Wanderer'), findsOneWidget);
  });
}