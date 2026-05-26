import 'package:blindbox_app/core/theme/app_theme.dart';
import 'package:blindbox_app/features/catalog/application/catalog_bundle_provider.dart';
import 'package:blindbox_app/features/catalog/catalog_seed_loader.dart';
import 'package:blindbox_app/features/collection/application/collection_notifier.dart';
import 'package:blindbox_app/features/collection/data/collection_memory_store.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/collection/insights/application/collector_type_providers.dart';
import 'package:blindbox_app/features/collection/insights/application/collector_type_resolver.dart';
import 'package:blindbox_app/features/collection/insights/domain/collector_type_archetype.dart';
import 'package:blindbox_app/features/collection/insights/domain/collector_type_identity.dart';
import 'package:blindbox_app/features/collection/insights/domain/collector_type_stats.dart';
import 'package:blindbox_app/features/collection/insights/presentation/collector_type_copy.dart';
import 'package:blindbox_app/features/collection/insights/widgets/collector_type_reveal_card.dart';
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

  final _emptyCatalog = const CatalogSeedBundle(
    brands: [],
    ips: [],
    series: [],
    figures: [],
  );

  Widget wrap(Widget child, {List<Override> overrides = const []}) {
    return ProviderScope(
      overrides: [
        collectionNotifierProvider.overrideWith(RevealCardTestNotifier.new),
        catalogBundleProvider.overrideWith((ref) async => _emptyCatalog),
        ...overrides,
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(body: child),
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

  testWidgets('cached identity idle shows result and reveal again', (tester) async {
    await CollectionMemoryStore.instance.saveCollectorType(
      CollectorTypeIdentity(
        archetypeId: CollectorTypeArchetypeId.wanderer,
        revealedAt: DateTime(2026, 1, 1),
        signatureHash: 'x',
        stats: const CollectorTypeStats(
          totalOwned: 0,
          totalWishlist: 0,
          trackedSeries: 1,
          completionPercent: 0,
          secretOwned: 0,
          secretSlots: 0,
          brandBreakdown: {},
          topSeries: [],
          customSeriesRatio: 0,
        ),
      ),
    );

    await tester.pumpWidget(wrap(const CollectorTypeRevealCard()));
    await tester.pump();

    expect(find.text('The Wanderer'), findsOneWidget);
    expect(find.text(CollectorTypeCopy.revealAgain), findsOneWidget);
  });
}
