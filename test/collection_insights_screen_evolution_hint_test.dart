import 'package:blindbox_app/core/theme/app_theme.dart';
import 'package:blindbox_app/features/catalog/application/catalog_bundle_provider.dart';
import 'package:blindbox_app/features/catalog/catalog_seed_loader.dart';
import 'package:blindbox_app/features/collection/application/collection_notifier.dart';
import 'package:blindbox_app/features/collection/data/collection_memory_store.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/collection/insights/application/collector_type_providers.dart';
import 'package:blindbox_app/features/collection/insights/presentation/collector_type_copy.dart';
import 'package:blindbox_app/features/collection/insights/presentation/collection_insights_screen.dart';
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
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          collectionNotifierProvider.overrideWith(InsightsHintTestNotifier.new),
          collectorTypeEvolutionHintProvider.overrideWith((ref) => showHint),
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

  testWidgets('hides evolution hint when provider is false', (tester) async {
    await pumpScreen(tester, showHint: false);
    expect(find.text(CollectorTypeCopy.evolutionHint), findsNothing);
  });
}
