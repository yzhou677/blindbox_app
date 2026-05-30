import 'dart:io';

import 'package:blindbox_app/features/catalog/application/catalog_bundle_cache.dart';
import 'package:blindbox_app/features/catalog/catalog_image_resolver.dart';
import 'package:blindbox_app/features/catalog/data/catalog_image_disk_cache.dart';
import 'package:blindbox_app/features/catalog/catalog_seed_loader.dart';
import 'package:blindbox_app/features/catalog/models/catalog_brand.dart';
import 'package:blindbox_app/features/catalog/models/catalog_figure.dart';
import 'package:blindbox_app/features/catalog/models/catalog_ip.dart';
import 'package:blindbox_app/features/catalog/models/catalog_series.dart';
import 'package:blindbox_app/features/collection/application/collection_notifier.dart';
import 'package:blindbox_app/features/collection/data/custom_series_conventions.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart'
    show CollectionSnapshot, ShelfFigure, ShelfSeries;
import 'package:blindbox_app/features/collection/widgets/add_to_collection_sheet.dart';
import 'package:blindbox_app/shared/widgets/collectible_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _SeededCollectionNotifier extends CollectionNotifier {
  _SeededCollectionNotifier(this._snapshot);
  final CollectionSnapshot _snapshot;

  @override
  CollectionSnapshot build() => _snapshot;

  void setSnapshot(CollectionSnapshot next) {
    state = next;
  }
}

CatalogSeedBundle _bundle() {
  const brandId = 'nyota';
  const ipId = 'where_moments_meet_ip';
  const seriesId = 'where_moments_meet';
  return const CatalogSeedBundle(
    brands: [
      CatalogBrand(id: brandId, displayName: 'Nyota'),
    ],
    ips: [
      CatalogIp(id: ipId, brandId: brandId, displayName: 'Where Moments Meet'),
    ],
    series: [
      CatalogSeries(
        id: seriesId,
        brandId: brandId,
        ipId: ipId,
        displayName: 'Where Moments Meet Series Plush Doll',
        releaseDate: '2026-01-01',
        isBlindBox: true,
        imageKey: seriesId,
      ),
    ],
    figures: [
      CatalogFigure(
        id: 'where_moments_meet_fig_1',
        seriesId: seriesId,
        brandId: brandId,
        ipId: ipId,
        displayName: 'Where Moments Meet Plush Doll',
        isSecret: false,
        sortOrder: 0,
        imageKey: 'where_moments_meet_fig_1',
      ),
    ],
  );
}

Future<void> _pumpSheet(
  WidgetTester tester,
  ProviderContainer container,
) async {
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: Scaffold(
          body: CollectibleSheetScope(
            scrollController: ScrollController(),
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

Finder _row(String seriesId) =>
    find.byKey(ValueKey<String>('add-series-search:$seriesId'));

Finder _inRow(String seriesId, Finder finder) {
  return find.descendant(of: _row(seriesId), matching: finder);
}

void main() {
  const seriesId = 'where_moments_meet';

  late Directory tempCacheRoot;

  setUp(() async {
    tempCacheRoot = await Directory.systemTemp.createTemp('add_sheet_own_test_');
    CatalogImageDiskCache.testRootOverride = tempCacheRoot;
    CatalogImageResolver.storageFallbackOverride = false;
    CatalogImageResolver.resetSessionCachesForTest();
    CatalogBundleCache.prime(_bundle());
  });

  tearDown(() async {
    CatalogImageResolver.resetSessionCachesForTest();
    CatalogImageDiskCache.resetForTest();
    if (await tempCacheRoot.exists()) {
      await tempCacheRoot.delete(recursive: true);
    }
  });

  testWidgets('add from search keeps result visible and switches CTA to owned', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        collectionNotifierProvider.overrideWith(
          () => _SeededCollectionNotifier(CollectionSnapshot.emptyTest()),
        ),
      ],
    );

    await _pumpSheet(tester, container);
    await tester.enterText(find.byType(TextField), 'where');
    await tester.pumpAndSettle();

    expect(_row(seriesId), findsOneWidget);
    expect(_inRow(seriesId, find.text('Add')), findsOneWidget);

    await tester.tap(_inRow(seriesId, find.text('Add')));
    await tester.pumpAndSettle();

    expect(_row(seriesId), findsOneWidget);
    expect(_inRow(seriesId, find.text('In collection')), findsOneWidget);
    expect(_inRow(seriesId, find.text('Add')), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    container.dispose();
    await tester.pump();
  });

  testWidgets('removing from collection restores search CTA to add', (tester) async {
    final seeded = CollectionSnapshot(
      shelfSeries: const [
        ShelfSeries(
          id: 'shelf-1',
          name: 'Where Moments Meet Series Plush Doll',
          brand: 'Nyota',
          ipName: 'Where Moments Meet',
          figures: [
            ShelfFigure(
              id: 'fig-1',
              seriesId: 'shelf-1',
              name: 'Where Moments Meet Plush Doll',
              rarity: 'Regular',
              isSecret: false,
            ),
          ],
          shelfAccent: Color(0xFFE8DEF5),
          catalogTemplateId: seriesId,
        ),
      ],
      figureStates: {},
    );
    final container = ProviderContainer(
      overrides: [
        collectionNotifierProvider.overrideWith(
          () => _SeededCollectionNotifier(seeded),
        ),
      ],
    );

    await _pumpSheet(tester, container);
    await tester.enterText(find.byType(TextField), 'where');
    await tester.pumpAndSettle();

    expect(_inRow(seriesId, find.text('In collection')), findsOneWidget);

    final notifier =
        container.read(collectionNotifierProvider.notifier) as _SeededCollectionNotifier;
    notifier.setSnapshot(CollectionSnapshot.emptyTest());
    await tester.pumpAndSettle();

    expect(_row(seriesId), findsOneWidget);
    expect(_inRow(seriesId, find.text('Add')), findsOneWidget);
    expect(_inRow(seriesId, find.text('In collection')), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    container.dispose();
    await tester.pump();
  });

  testWidgets('canonical custom matches show owned state in search', (tester) async {
    final container = ProviderContainer(
      overrides: [
        collectionNotifierProvider.overrideWith(
          () => _SeededCollectionNotifier(CollectionSnapshot.emptyTest()),
        ),
      ],
    );

    container.read(collectionNotifierProvider.notifier).addCustomSeries(
          seriesName: 'Where-Moments Meet Series Plush Doll',
          brand: 'N Y O T A',
          figures: const [CustomFigureDraft(displayName: 'Custom Figure')],
        );

    await _pumpSheet(tester, container);
    await tester.enterText(find.byType(TextField), 'where moments');
    await tester.pumpAndSettle();

    expect(_row(seriesId), findsOneWidget);
    expect(_inRow(seriesId, find.text('In collection')), findsOneWidget);
    expect(_inRow(seriesId, find.text('Add')), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    container.dispose();
    await tester.pump();
  });
}
