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
import 'package:blindbox_app/features/collection/insights/presentation/collector_type_copy.dart';
import 'package:blindbox_app/features/collection/insights/presentation/collection_insights_screen.dart';
import 'package:blindbox_app/features/collection/insights/widgets/collector_type_reveal_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/collection_fixtures.dart';

final class OverflowTestNotifier extends CollectionNotifier {
  @override
  CollectionSnapshot build() => CollectionSnapshot(
        shelfSeries: [testShelfSeries()],
        figureStates: const {},
      );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    CollectionMemoryStore.instance.resetForTest();
    await CollectionMemoryStore.instance.saveCollectorType(
      CollectorTypeIdentity(
        archetypeId: CollectorTypeArchetypeId.wanderer,
        revealedAt: DateTime(2026, 1, 1),
        signatureHash: 'stale-overflow-signature',
        stats: const CollectorTypeStats(
          totalOwned: 0,
          totalWishlist: 0,
          trackedSeries: 1,
          completedSeriesCount: 0,
          masterCompleteSeriesCount: 0,
          completionPercent: 0,
          secretOwned: 0,
          secretSlots: 0,
          brandBreakdown: {},
          topSeries: [],
          customSeriesRatio: 0,
        ),
      ),
    );
  });

  testWidgets('overflow reveal again triggers analyzing', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          collectionNotifierProvider.overrideWith(OverflowTestNotifier.new),
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

    expect(find.byType(CollectorTypeRevealCard), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: find.byType(CollectorTypeRevealCard),
        matching: find.text(CollectorTypeCopy.revealAgain),
      ),
    );
    await tester.pump();

    expect(find.text(CollectorTypeCopy.analyzingLine), findsOneWidget);

    await tester.pump(const Duration(milliseconds: collectorTypeAnalyzingHoldMs));
    await tester.pump(const Duration(milliseconds: 400));
  });
}
