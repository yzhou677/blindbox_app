import 'package:blindbox_app/core/theme/app_theme.dart';
import 'package:blindbox_app/features/catalog/application/catalog_bundle_provider.dart';
import 'package:blindbox_app/features/catalog/catalog_bundle.dart';
import 'package:blindbox_app/features/collection/application/collection_notifier.dart';
import 'package:blindbox_app/features/collection/collection_screen.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/collection_fixtures.dart';

final class _IpFilterTestCollectionNotifier extends CollectionNotifier {
  _IpFilterTestCollectionNotifier(this._snap);
  final CollectionSnapshot _snap;

  @override
  CollectionSnapshot build() => _snap;
}

void main() {
  testWidgets('addSeriesFromTemplate surfaces new IP chip immediately', (
    tester,
  ) async {
    final existing = testShelfSeries(
      id: 'existing',
      ipName: 'Hirono',
      taxonomyIpId: 'hirono',
    );
    final nyotaTemplate = CatalogSeries(
      templateId: 'nyota_series',
      name: 'Nyota Series',
      brand: 'POP MART',
      ipName: 'Nyota',
      shelfAccent: const Color(0xFFE4F2EA),
      taxonomyBrandId: 'pop_mart',
      taxonomyIpId: 'nyota',
      figures: testCatalogTemplate(templateId: 'nyota_series').figures,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          collectionNotifierProvider.overrideWith(
            () => _IpFilterTestCollectionNotifier(
              CollectionSnapshot(
                shelfSeries: [existing],
                figureStates: const {},
              ),
            ),
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
          home: const CollectionScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    await tester.tap(find.byKey(const Key('collection_shelf_filters_control')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Nyota'), findsNothing);
    await tester.tap(find.byKey(const Key('filters_sheet_show_results')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final container = ProviderScope.containerOf(
      tester.element(find.byType(CollectionScreen)),
    );
    container
        .read(collectionNotifierProvider.notifier)
        .addSeriesFromTemplate(nyotaTemplate);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    await tester.tap(find.byKey(const Key('collection_shelf_filters_control')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Nyota'), findsAtLeastNWidgets(1));
    expect(find.text('Brand'), findsOneWidget);
    expect(find.text('IP'), findsOneWidget);
    // Collapsed Brand/IP facet summary uses [filterFacetAllSummary] ("All").
    expect(find.text('All'), findsWidgets);

    // Flush CollectionNotifier persistence debounce timer.
    await tester.pump(const Duration(milliseconds: 400));
  });
}
