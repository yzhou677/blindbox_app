import 'package:blindbox_app/core/firebase/ensure_firebase_initialized.dart';
import 'package:blindbox_app/features/catalog/application/catalog_bundle_cache.dart';
import 'package:blindbox_app/features/market/catalog/market_taxonomy.dart';
import 'package:blindbox_app/core/router/app_router.dart';
import 'package:blindbox_app/core/theme/app_theme.dart';
import 'package:blindbox_app/features/collection/bootstrap/collection_app_bootstrap.dart';
import 'package:blindbox_app/features/collection/data/collection_seed_data.dart';
import 'package:blindbox_app/features/collection/data/series_release_lookup.dart';
import 'package:blindbox_app/features/collection/persistence/collection_snapshot_storage.dart';
import 'package:blindbox_app/features/home/application/home_feed_provider.dart';
import 'package:blindbox_app/features/market/data/market_catalog_identity_cache.dart';
import 'package:blindbox_app/features/market/data/market_listings_bootstrap.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await ensureFirebaseInitialized();
  } catch (e, st) {
    debugPrint('Firebase init skipped: $e\n$st');
  }
  try {
    final catalogBundle = await CatalogBundleCache.loadOfflineFirst();
    MarketTaxonomy.applyCatalogBundle(catalogBundle);
    MarketCatalogIdentityCache.install(catalogBundle);
  } catch (e, st) {
    debugPrint('Catalog seed bootstrap skipped: $e\n$st');
  }
  await bootstrapMarketBrowseListings();
  final restored = await CollectionSnapshotStorage.load();
  CollectionAppBootstrap.prime(restored ?? CollectionSeedData.initialSnapshot());
  runApp(
    ProviderScope(
      overrides: [
        seriesReleaseLookupProvider.overrideWith(
          (ref) => ref.watch(homeSeriesReleaseLookupProvider),
        ),
      ],
      child: const BlindboxApp(),
    ),
  );
}

class BlindboxApp extends StatelessWidget {
  const BlindboxApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Blind Box',
      debugShowCheckedModeBanner: false, 
      themeMode: ThemeMode.system,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      routerConfig: appRouter,
    );
  }
}
