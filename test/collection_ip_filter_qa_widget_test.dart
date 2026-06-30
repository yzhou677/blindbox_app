import 'package:blindbox_app/core/theme/app_theme.dart';
import 'package:blindbox_app/features/catalog/application/catalog_bundle_provider.dart';
import 'package:blindbox_app/features/catalog/catalog_bundle.dart';
import 'package:blindbox_app/features/collection/application/collection_notifier.dart';
import 'package:blindbox_app/features/collection/collection_screen.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/collection/presentation/collection_shelf_brand_facets.dart';
import 'package:blindbox_app/features/collection/presentation/collection_shelf_ip_facets.dart';
import 'package:blindbox_app/features/collection/widgets/collection_brand_filter_row.dart';
import 'package:blindbox_app/features/collection/widgets/collection_ip_filter_row.dart';
import 'package:blindbox_app/shared/widgets/taxonomy_brand_chip_rail.dart';
import 'package:blindbox_app/shared/widgets/taxonomy_filter_section_label.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'helpers/collection_fixtures.dart';

final class _QaCollectionNotifier extends CollectionNotifier {
  _QaCollectionNotifier(this._snap);
  final CollectionSnapshot _snap;

  @override
  CollectionSnapshot build() => _snap;
}

Widget _qaHarness(CollectionSnapshot snap) {
  return ProviderScope(
    overrides: [
      collectionNotifierProvider.overrideWith(() => _QaCollectionNotifier(snap)),
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
      home: RepaintBoundary(
        key: const Key('qa_collection_screenshot'),
        child: const CollectionScreen(),
      ),
    ),
  );
}

List<ShelfSeries> _populatedDemoShelf() {
  return [
    testShelfSeries(
      id: 'pop_hirono_1',
      name: 'Hirono — The Other One',
      brand: 'POP MART',
      ipName: 'Hirono',
      taxonomyBrandId: 'pop_mart',
      taxonomyIpId: 'hirono',
      catalogTemplateId: 'cat_hirono_1',
    ),
    testShelfSeries(
      id: 'pop_hirono_2',
      name: 'Hirono — Falling',
      brand: 'POP MART',
      ipName: 'Hirono',
      taxonomyBrandId: 'pop_mart',
      taxonomyIpId: 'hirono',
      catalogTemplateId: 'cat_hirono_2',
    ),
    testShelfSeries(
      id: 'pop_skull',
      name: 'Skullpanda — Warmth',
      brand: 'POP MART',
      ipName: 'Skullpanda',
      taxonomyBrandId: 'pop_mart',
      taxonomyIpId: 'skullpanda',
      catalogTemplateId: 'cat_skull',
    ),
    testShelfSeries(
      id: 'pop_sanrio',
      name: 'Sanrio — My Melody',
      brand: 'POP MART',
      ipName: 'Sanrio',
      taxonomyBrandId: 'pop_mart',
      taxonomyIpId: 'sanrio',
      catalogTemplateId: 'cat_sanrio',
    ),
    testShelfSeries(
      id: 'top_tnt',
      name: 'TNT SPACE — Rayan',
      brand: 'TOP TOY',
      ipName: 'TNT SPACE',
      taxonomyBrandId: 'toptoy',
      taxonomyIpId: 'tnt_space',
      catalogTemplateId: 'cat_tnt',
    ),
  ];
}

List<ShelfSeries> _stressShelfDistinctIps(int count) {
  return [
    for (var i = 0; i < count; i++)
      testShelfSeries(
        id: 'stress_$i',
        name: 'Series $i',
        brand: 'POP MART',
        ipName: 'Unique IP $i',
        taxonomyBrandId: 'pop_mart',
        taxonomyIpId: 'unique_ip_$i',
        catalogTemplateId: 'cat_stress_$i',
      ),
  ];
}

Finder _brandChipLabel(String label) => find.descendant(
      of: find.byType(TaxonomyBrandChipRail).first,
      matching: find.text(label),
    );

Finder _ipChipLabel(String label) => find.descendant(
      of: find.byType(TaxonomyBrandChipRail).last,
      matching: find.text(label),
    );

/// Goldens use system fonts so labels render without google_fonts network fetch.
ThemeData _qaScreenshotTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: const Color(0xFFA892CC));
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: Color.lerp(
      scheme.surfaceContainerLow,
      scheme.surface,
      0.42,
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('stress: 50 IP chips in rail — narrow width, scroll, no rail overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 200);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    final shelf = _stressShelfDistinctIps(50);
    final brandOptions = buildCollectionShelfBrandFilterOptions(shelf);
    final ipOptions = buildCollectionShelfIpFilterOptions(shelf);

    await tester.pumpWidget(
      MaterialApp(
        theme: _qaScreenshotTheme(),
        home: RepaintBoundary(
          key: const Key('qa_collection_screenshot'),
          child: Scaffold(
            body: SizedBox(
              width: 360,
              child: Column(
                children: [
                  CollectionBrandFilterRow(
                    options: brandOptions,
                    selectedBrandId: collectionAnyBrandFilterId,
                    onBrandSelected: (_) {},
                  ),
                  const SizedBox(height: 6),
                  CollectionIpFilterRow(
                    options: ipOptions,
                    selectedIpId: collectionAnyIpFilterId,
                    onIpSelected: (_) {},
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byType(TaxonomyBrandChipRail), findsNWidgets(2));

    final ipRail = find.byType(TaxonomyBrandChipRail).last;
    for (var i = 0; i < 12; i++) {
      await tester.drag(ipRail, const Offset(-160, 0));
      await tester.pump();
    }
    expect(ipOptions.length, 51);
    expect(find.byType(TaxonomyBrandChipRail), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('populated shelf screenshot for documentation', (tester) async {
    tester.view.physicalSize = const Size(412, 820);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    final shelf = _populatedDemoShelf();
    final brandOptions = buildCollectionShelfBrandFilterOptions(shelf);
    final ipOptions = buildCollectionShelfIpFilterOptions(shelf);

    final theme = _qaScreenshotTheme();
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: RepaintBoundary(
          key: const Key('qa_collection_screenshot'),
          child: Scaffold(
            backgroundColor: theme.scaffoldBackgroundColor,
            body: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(0, 8, 0, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      'My collection',
                      style: theme.textTheme.titleLarge,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const TaxonomyFilterSectionLabel(text: 'Brand'),
                  const SizedBox(height: 6),
                  CollectionBrandFilterRow(
                    options: brandOptions,
                    selectedBrandId: collectionAnyBrandFilterId,
                    onBrandSelected: (_) {},
                  ),
                  const SizedBox(height: 14),
                  const TaxonomyFilterSectionLabel(text: 'IP'),
                  const SizedBox(height: 6),
                  CollectionIpFilterRow(
                    options: ipOptions,
                    selectedIpId: collectionAnyIpFilterId,
                    onIpSelected: (_) {},
                  ),
                  const SizedBox(height: 12),
                  for (final series in shelf)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: series.shelfAccent.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: ListTile(
                          title: Text(series.name),
                          subtitle: Text(
                            '${series.brand} · ${shelfSeriesIpLabel(series)}',
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(CollectionBrandFilterRow), findsOneWidget);
    expect(find.byType(CollectionIpFilterRow), findsOneWidget);
    expect(find.text('Brand'), findsOneWidget);
    expect(find.text('IP'), findsOneWidget);
    expect(find.text('All Brands'), findsOneWidget);
    expect(find.text('All IPs'), findsOneWidget);
    expect(find.text('Hirono — The Other One'), findsOneWidget);

    await expectLater(
      find.byKey(const Key('qa_collection_screenshot')),
      matchesGoldenFile('goldens/collection_ip_filter_populated.png'),
    );
  });

  testWidgets('stress rail golden for documentation', (tester) async {
    tester.view.physicalSize = const Size(360, 120);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    final shelf = _stressShelfDistinctIps(50);
    final ipOptions = buildCollectionShelfIpFilterOptions(shelf);

    await tester.pumpWidget(
      MaterialApp(
        theme: _qaScreenshotTheme(),
        home: RepaintBoundary(
          key: const Key('qa_collection_screenshot'),
          child: Scaffold(
            body: SizedBox(
              width: 360,
              child: CollectionIpFilterRow(
                options: ipOptions,
                selectedIpId: collectionAnyIpFilterId,
                onIpSelected: (_) {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await expectLater(
      find.byKey(const Key('qa_collection_screenshot')),
      matchesGoldenFile('goldens/collection_ip_filter_stress_50_ips.png'),
    );
  });

  testWidgets('brand/IP interaction matches expected selection rules', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(480, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final shelf = _populatedDemoShelf();
    await tester.pumpWidget(
      _qaHarness(CollectionSnapshot(shelfSeries: shelf, figureStates: const {})),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // All + select IP Hirono
    await tester.tap(_ipChipLabel('Hirono'));
    await tester.pump();

    final allHirono = shelfSeriesVisibleForIpFilter(
      shelfSeriesVisibleForBrandFilter(shelf, collectionAnyBrandFilterId),
      'hirono',
    );
    expect(allHirono.length, 2);
    expect(find.text('Hirono — The Other One'), findsOneWidget);
    expect(find.text('Skullpanda — Warmth'), findsNothing);

    // Brand POP MART — Hirono should stay selected (code + UI)
    final popMartScoped = shelfSeriesVisibleForBrandFilter(shelf, 'popmart');
    final ipOptionsAfterPopMart = buildCollectionShelfIpFilterOptions(
      popMartScoped,
    );
    expect(
      resolveCollectionIpFilterSelection(
        selectedIpFilterId: 'hirono',
        options: ipOptionsAfterPopMart,
      ),
      'hirono',
    );

    await tester.ensureVisible(_brandChipLabel('POP MART'));
    await tester.tap(_brandChipLabel('POP MART'));
    await tester.pump();
    expect(find.text('Hirono — The Other One'), findsOneWidget);
    expect(find.text('TNT SPACE — Rayan'), findsNothing);

    // Brand TOP TOY — Hirono chip gone, selection resets to All
    final topScoped = shelfSeriesVisibleForBrandFilter(shelf, 'toptoy');
    final ipOptionsAfterTopToy = buildCollectionShelfIpFilterOptions(topScoped);
    expect(
      resolveCollectionIpFilterSelection(
        selectedIpFilterId: 'hirono',
        options: ipOptionsAfterTopToy,
      ),
      collectionAnyIpFilterId,
    );

    await tester.ensureVisible(_brandChipLabel('TOP TOY'));
    await tester.tap(_brandChipLabel('TOP TOY'));
    await tester.pump();
    await tester.ensureVisible(find.text('TNT SPACE — Rayan'));
    expect(find.text('TNT SPACE — Rayan'), findsOneWidget);
    expect(find.text('Hirono — The Other One'), findsNothing);
  });
}
