import 'dart:io';

import 'package:blindbox_app/features/catalog/application/catalog_bundle_cache.dart';
import 'package:blindbox_app/features/catalog/catalog_image_resolver.dart';
import 'package:blindbox_app/features/catalog/data/catalog_image_disk_cache.dart';
import 'package:blindbox_app/features/catalog/catalog_bundle.dart';
import 'package:blindbox_app/features/catalog/models/catalog_brand.dart';
import 'package:blindbox_app/features/catalog/models/catalog_figure.dart';
import 'package:blindbox_app/features/catalog/models/catalog_ip.dart';
import 'package:blindbox_app/features/catalog/models/catalog_series.dart';
import 'package:blindbox_app/features/catalog/search/catalog_search_history_provider.dart';
import 'package:blindbox_app/features/collection/application/collection_notifier.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart'
    show CollectionSnapshot;
import 'package:blindbox_app/features/collection/presentation/add_series_catalog_copy.dart';
import 'package:blindbox_app/features/collection/widgets/add_to_collection_sheet.dart';
import 'package:blindbox_app/shared/widgets/collectible_bottom_sheet.dart';
import 'package:blindbox_app/shared/widgets/collectible_browse_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _SeededCollectionNotifier extends CollectionNotifier {
  _SeededCollectionNotifier(this._snapshot);
  final CollectionSnapshot _snapshot;

  @override
  CollectionSnapshot build() => _snapshot;
}

CatalogSeedBundle _browseBundle() {
  return CatalogSeedBundle(
    brands: const [
      CatalogBrand(id: 'popmart', displayName: 'POP MART'),
    ],
    ips: const [
      CatalogIp(id: 'popmart', brandId: 'popmart', displayName: 'POP MART'),
    ],
    series: [
      for (var i = 0; i < 8; i++)
        CatalogSeries(
          id: 'series_$i',
          brandId: 'popmart',
          ipId: 'popmart',
          displayName: 'Series $i',
          releaseDate: '2026-05-${(20 - i).toString().padLeft(2, '0')}',
          isBlindBox: true,
          imageKey: 'series_$i',
        ),
    ],
    figures: [
      for (var i = 0; i < 8; i++)
        CatalogFigure(
          id: 'series_${i}_fig',
          seriesId: 'series_$i',
          brandId: 'popmart',
          ipId: 'popmart',
          displayName: 'Figure $i',
          isSecret: false,
          sortOrder: 0,
          imageKey: 'series_${i}_fig',
        ),
    ],
  );
}

Future<void> _pumpSheet(
  WidgetTester tester,
  ProviderContainer container, {
  ScrollController? scrollController,
}) async {
  final scroll = scrollController ?? ScrollController();
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: Scaffold(
          body: CollectibleSheetScope(
            scrollController: scroll,
            child: AddToCollectionSheet(
              onCreateCustom: () {},
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

Finder get _searchField => find.byType(TextField);

void main() {
  late Directory tempCacheRoot;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    tempCacheRoot = await Directory.systemTemp.createTemp('add_sheet_own_test_');
    CatalogImageDiskCache.testRootOverride = tempCacheRoot;
    CatalogImageResolver.storageFallbackOverride = false;
    CatalogImageResolver.resetSessionCachesForTest();
    CatalogBundleCache.prime(_browseBundle());
  });

  tearDown(() async {
    CatalogImageResolver.resetSessionCachesForTest();
    CatalogImageDiskCache.resetForTest();
    if (await tempCacheRoot.exists()) {
      await tempCacheRoot.delete(recursive: true);
    }
  });

  testWidgets('shows Browse heading when query is empty', (tester) async {
    final container = ProviderContainer(
      overrides: [
        collectionNotifierProvider.overrideWith(
          () => _SeededCollectionNotifier(CollectionSnapshot.emptyTest()),
        ),
      ],
    );
    addTearDown(container.dispose);

    await _pumpSheet(tester, container);
    await tester.pumpAndSettle();

    expect(find.text(AddSeriesCatalogCopy.browseHeading), findsOneWidget);
    expect(find.byKey(const Key('catalog-photo-action')), findsOneWidget);
    expect(find.text('Latest releases'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('typing replaces Browse with shared catalog search results', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        collectionNotifierProvider.overrideWith(
          () => _SeededCollectionNotifier(CollectionSnapshot.emptyTest()),
        ),
      ],
    );
    addTearDown(container.dispose);

    await _pumpSheet(tester, container);
    await tester.pumpAndSettle();

    await tester.enterText(_searchField, 'Series 1');
    await tester.pump();

    expect(find.text(AddSeriesCatalogCopy.browseHeading), findsNothing);
    expect(find.text('Matches'), findsOneWidget);
    expect(find.widgetWithText(CollectibleBrowseCard, 'Series 1'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('search writes to shared catalog history', (tester) async {
    final container = ProviderContainer(
      overrides: [
        collectionNotifierProvider.overrideWith(
          () => _SeededCollectionNotifier(CollectionSnapshot.emptyTest()),
        ),
      ],
    );
    addTearDown(container.dispose);

    await _pumpSheet(tester, container);
    await tester.pumpAndSettle();

    await tester.enterText(_searchField, 'popmart');
    await tester.pump();
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pump();

    expect(container.read(catalogSearchHistoryProvider), ['popmart']);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('browse add avoids reload spinner and updates CTA in place', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        collectionNotifierProvider.overrideWith(
          () => _SeededCollectionNotifier(CollectionSnapshot.emptyTest()),
        ),
      ],
    );
    addTearDown(container.dispose);

    await _pumpSheet(tester, container);
    await tester.pumpAndSettle();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    final addButton = find.text('Add').first;
    await tester.ensureVisible(addButton);
    await tester.tap(addButton);
    await tester.pumpAndSettle();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('In collection'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 400));
    container.dispose();
    await tester.pump();
  });
}
