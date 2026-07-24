import 'package:blindbox_app/core/firebase/ensure_firebase_initialized.dart';
import 'package:blindbox_app/core/firebase/activate_firebase_app_check.dart';
import 'package:blindbox_app/features/catalog/application/catalog_bundle_cache.dart';
import 'package:blindbox_app/core/router/app_router.dart';
import 'package:blindbox_app/core/theme/app_theme.dart';
import 'package:blindbox_app/features/collection/bootstrap/collection_app_bootstrap.dart';
import 'package:blindbox_app/features/collection/data/collection_seed_data.dart';
import 'package:blindbox_app/features/collection/data/series_release_lookup.dart';
import 'package:blindbox_app/features/collection/data/collection_memory_store.dart';
import 'package:blindbox_app/features/collection/persistence/collection_snapshot_storage.dart';
import 'package:blindbox_app/features/home/application/catalog_bundle_refresh_bridge.dart';
import 'package:blindbox_app/features/home/application/home_feed_provider.dart';
import 'package:blindbox_app/features/market/data/market_catalog_identity_cache.dart';
import 'package:blindbox_app/features/collection/widgets/master_complete_celebration_host.dart';
import 'package:blindbox_app/features/collection/widget/on_display_widget_sync.dart';
import 'package:blindbox_app/features/market/data/market_listings_bootstrap.dart';
import 'package:blindbox_app/features/recommendations/application/recommendation_sync_notifier.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await ensureFirebaseInitialized();
    await activateFirebaseAppCheck();
  } catch (e, st) {
    debugPrint('Firebase init skipped: $e\n$st');
  }
  try {
    final catalogBundle = await CatalogBundleCache.loadOfflineFirst();
    // Identity index syncs via [catalogBundleProvider] once the revision
    // listener is active; prime here for pre-ProviderScope enricher paths.
    MarketCatalogIdentityCache.install(catalogBundle);
  } catch (e, st) {
    debugPrint('Catalog offline-first bootstrap skipped: $e\n$st');
  }
  await bootstrapMarketBrowseListings();
  final restored = await CollectionSnapshotStorage.load();
  final snapshot = restored ?? CollectionSeedData.initialSnapshot();
  CollectionAppBootstrap.prime(snapshot);
  await CollectionMemoryStore.instance.ensureLoaded();
  runApp(
    ProviderScope(
      overrides: [
        seriesReleaseLookupProvider.overrideWith(
          (ref) => ref.watch(homeSeriesReleaseLookupProvider),
        ),
      ],
      child: const CatalogBundleRefreshBridge(child: BlindboxApp()),
    ),
  );
}

class BlindboxApp extends ConsumerWidget {
  const BlindboxApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Eagerly start recommendation profile synchronization.
    // This is app-level infrastructure and intentionally independent
    // of whether Discover is visited. The notifier calls keepAlive() so
    // it persists for the full app session; ref.read does not subscribe.
    ref.read(recommendationSyncProvider);

    return MaterialApp.router(
      title: 'Shelfy',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.system,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      routerConfig: appRouter,
      builder: (context, child) {
        return OnDisplayWidgetSyncHost(
          child: MasterCompleteCelebrationHost(
            child: child ?? const SizedBox.shrink(),
          ),
        );
      },
    );
  }
}
