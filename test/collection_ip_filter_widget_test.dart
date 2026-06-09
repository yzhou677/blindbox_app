import 'package:blindbox_app/core/theme/app_theme.dart';
import 'package:blindbox_app/features/collection/application/collection_notifier.dart';
import 'package:blindbox_app/features/collection/collection_screen.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/shared/widgets/taxonomy_brand_chip_rail.dart';
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
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const CollectionScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Nyota'), findsNothing);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(CollectionScreen)),
    );
    container.read(collectionNotifierProvider.notifier).addSeriesFromTemplate(
          nyotaTemplate,
        );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Nyota'), findsAtLeastNWidgets(1));
    expect(find.byType(TaxonomyBrandChipRail), findsNWidgets(2));

    // Flush CollectionNotifier persistence debounce timer.
    await tester.pump(const Duration(milliseconds: 400));
  });
}
