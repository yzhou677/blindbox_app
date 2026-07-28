import 'dart:io';

import 'package:blindbox_app/core/theme/app_theme.dart';
import 'package:blindbox_app/features/catalog/application/catalog_bundle_cache.dart';
import 'package:blindbox_app/features/catalog/catalog_bundle.dart';
import 'package:blindbox_app/features/catalog/catalog_image_resolver.dart';
import 'package:blindbox_app/features/catalog/data/catalog_image_disk_cache.dart';
import 'package:blindbox_app/features/catalog/models/catalog_brand.dart';
import 'package:blindbox_app/features/catalog/models/catalog_figure.dart';
import 'package:blindbox_app/features/catalog/models/catalog_ip.dart';
import 'package:blindbox_app/features/catalog/models/catalog_series.dart'
    as catalog;
import 'package:blindbox_app/features/catalog/presentation/catalog_search_experience.dart';
import 'package:blindbox_app/features/collection/application/collection_notifier.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart'
    hide CatalogFigure;
import 'package:blindbox_app/features/collection/widgets/add_to_collection_sheet.dart';
import 'package:blindbox_app/shared/widgets/collectible_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

CatalogSeedBundle _bundle() {
  return const CatalogSeedBundle(
    brands: [CatalogBrand(id: 'nyota', displayName: 'Nyota')],
    ips: [
      CatalogIp(
        id: 'where_moments_meet_ip',
        brandId: 'nyota',
        displayName: 'Where Moments Meet',
      ),
    ],
    series: [
      catalog.CatalogSeries(
        id: 'where_moments_meet',
        brandId: 'nyota',
        ipId: 'where_moments_meet_ip',
        displayName: 'Where Moments Meet Series Plush Doll',
        releaseDate: '2026-01-01',
        isBlindBox: true,
        imageKey: 'where_moments_meet',
      ),
    ],
    figures: [
      CatalogFigure(
        id: 'where_moments_meet_fig_1',
        seriesId: 'where_moments_meet',
        brandId: 'nyota',
        ipId: 'where_moments_meet_ip',
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

void main() {
  late Directory tempCacheRoot;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    CatalogSearchExperience.debugQueryActiveTrueCount = 0;
    CatalogSearchExperience.debugQueryActiveFalseCount = 0;
    CatalogSearchExperience.debugBuildCount = 0;
    CatalogSearchExperience.debugSearchExecutionCount = 0;
    tempCacheRoot = await Directory.systemTemp.createTemp('add_series_search_');
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

  testWidgets(
    'Add Series: rapid typing notifies queryActive once; search after settle',
    (tester) async {
      final scroll = ScrollController();
      addTearDown(scroll.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            collectionNotifierProvider.overrideWith(
              _EmptyCollectionNotifier.new,
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: Scaffold(
              body: CollectibleSheetScope(
                scrollController: scroll,
                child: AddToCollectionSheet(onCreateCustom: () {}),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      CatalogSearchExperience.debugQueryActiveTrueCount = 0;
      CatalogSearchExperience.debugBuildCount = 0;
      CatalogSearchExperience.debugSearchExecutionCount = 0;

      final field = find.byType(TextField);
      var typed = '';
      for (final ch in 'where'.split('')) {
        typed += ch;
        await tester.enterText(field, typed);
        await tester.pump();
      }

      expect(CatalogSearchExperience.debugQueryActiveTrueCount, 1);
      // Parent sheet setStates once on empty→active (hides browse chrome).
      expect(CatalogSearchExperience.debugBuildCount, lessThanOrEqualTo(1));
      expect(CatalogSearchExperience.debugSearchExecutionCount, 0);

      await tester.pump(const Duration(milliseconds: 249));
      expect(CatalogSearchExperience.debugSearchExecutionCount, 0);

      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump();

      expect(CatalogSearchExperience.debugSearchExecutionCount, 1);
      expect(find.text('Where Moments Meet Series Plush Doll'), findsWidgets);
    },
  );
}
