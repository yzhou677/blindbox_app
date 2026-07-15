import 'package:blindbox_app/core/theme/app_theme.dart';
import 'package:blindbox_app/features/catalog/application/catalog_bundle_provider.dart';
import 'package:blindbox_app/features/catalog/catalog_bundle.dart';
import 'package:blindbox_app/features/collection/application/collection_notifier.dart';
import 'package:blindbox_app/features/collection/data/collection_memory_store.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/collection/insights/application/collector_type_resolver.dart';
import 'package:blindbox_app/features/collection/insights/presentation/collector_type_copy.dart';
import 'package:blindbox_app/features/collection/insights/presentation/collection_insights_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/collection_fixtures.dart';

final class PopRegressionCollectionNotifier extends CollectionNotifier {
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

  testWidgets('pop during analyzing does not leave pending timer', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          collectionNotifierProvider.overrideWith(
            PopRegressionCollectionNotifier.new,
          ),
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
          home: Scaffold(
            body: Center(
              child: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).push<void>(
                      MaterialPageRoute<void>(
                        builder: (_) => const CollectionInsightsScreen(),
                      ),
                    );
                  },
                  child: const Text('open insights'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('open insights'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(CollectionInsightsScreen), findsOneWidget);

    final revealCta = find.text('Reveal collector type');
    final revealAgain = find.text(CollectorTypeCopy.revealAgain);
    expect(
      revealCta.evaluate().isNotEmpty || revealAgain.evaluate().isNotEmpty,
      isTrue,
    );
    if (revealCta.evaluate().isNotEmpty) {
      await tester.tap(revealCta.first);
    } else {
      await tester.tap(revealAgain.first);
    }
    await tester.pump();
    expect(find.text('Reading your shelf…'), findsOneWidget);

    Navigator.of(tester.element(find.byType(CollectionInsightsScreen))).pop();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(
      const Duration(milliseconds: collectorTypeAnalyzingHoldMs + 450),
    );

    expect(find.text('open insights'), findsOneWidget);
  });
}
