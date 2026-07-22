import 'dart:io';

import 'package:blindbox_app/core/theme/app_theme.dart';
import 'package:blindbox_app/features/catalog/application/catalog_bundle_cache.dart';
import 'package:blindbox_app/features/catalog/catalog_bundle.dart';
import 'package:blindbox_app/features/catalog/catalog_image_resolver.dart';
import 'package:blindbox_app/features/catalog/data/catalog_image_disk_cache.dart';
import 'package:blindbox_app/features/catalog/models/catalog_brand.dart';
import 'package:blindbox_app/features/catalog/models/catalog_figure.dart';
import 'package:blindbox_app/features/catalog/models/catalog_ip.dart';
import 'package:blindbox_app/features/catalog/models/catalog_series.dart';
import 'package:blindbox_app/features/catalog/presentation/catalog_browse_launch.dart';
import 'package:blindbox_app/features/catalog/presentation/catalog_browse_screen.dart';
import 'package:blindbox_app/features/catalog/presentation/catalog_search_experience.dart';
import 'package:blindbox_app/features/collection/application/collection_notifier.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart'
    show CollectionSnapshot;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

final class _EmptyCollectionNotifier extends CollectionNotifier {
  @override
  CollectionSnapshot build() => CollectionSnapshot.emptyTest();
}

Future<void> _pumpDiscoverSearch(WidgetTester tester) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        collectionNotifierProvider.overrideWith(_EmptyCollectionNotifier.new),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: const CatalogBrowseScreen(),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 200));
}

Finder get _searchField => find.byType(TextField);

void main() {
  late Directory tempCacheRoot;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    CatalogSearchExperience.debugBuildCount = 0;
    tempCacheRoot = await Directory.systemTemp.createTemp('discover_search_test_');
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

  testWidgets('single keystroke triggers exactly one screen rebuild', (tester) async {
    await _pumpDiscoverSearch(tester);
    expect(find.byKey(const Key('catalog-photo-action')), findsOneWidget);
    CatalogSearchExperience.debugBuildCount = 0;

    await tester.enterText(_searchField, 'w');
    await tester.pump();

    expect(
      CatalogSearchExperience.debugBuildCount,
      1,
      reason: 'live search should use a single onChanged setState path',
    );
  });

  testWidgets('live search still updates results every keystroke', (tester) async {
    await _pumpDiscoverSearch(tester);

    await tester.enterText(_searchField, 'where');
    await tester.pump();

    expect(
      find.text('Where Moments Meet Series Plush Doll'),
      findsOneWidget,
    );
    expect(find.text('Matches'), findsOneWidget);
  });

  testWidgets('launch prefills initial query from Add Series handoff', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          collectionNotifierProvider.overrideWith(_EmptyCollectionNotifier.new),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const CatalogBrowseScreen(
            launch: CatalogBrowseLaunch(initialQuery: 'where'),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('where'), findsOneWidget);
    expect(
      find.text('Where Moments Meet Series Plush Doll'),
      findsOneWidget,
    );
  });

  testWidgets('clear restores history chrome and drops matches', (tester) async {
    await _pumpDiscoverSearch(tester);

    await tester.enterText(_searchField, 'where');
    await tester.pump();
    expect(find.text('Matches'), findsOneWidget);

    await tester.tap(find.byTooltip('Clear'));
    await tester.pump();

    expect(find.text('Matches'), findsNothing);
    expect(
      find.text('Where Moments Meet Series Plush Doll'),
      findsNothing,
    );
  });
}
