import 'package:blindbox_app/core/router/app_router.dart';
import 'package:blindbox_app/core/theme/app_theme.dart';
import 'package:blindbox_app/features/collection/bootstrap/collection_app_bootstrap.dart';
import 'package:blindbox_app/features/collection/data/collection_seed_data.dart';
import 'package:blindbox_app/features/collection/data/series_release_lookup.dart';
import 'package:blindbox_app/features/collection/persistence/collection_snapshot_storage.dart';
import 'package:blindbox_app/features/home/data/mock_latest_drops.dart';
import 'package:blindbox_app/features/market/data/market_listings_bootstrap.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await bootstrapMarketBrowseListings();
  final restored = await CollectionSnapshotStorage.load();
  CollectionAppBootstrap.prime(restored ?? CollectionSeedData.initialSnapshot());
  runApp(
    ProviderScope(
      overrides: [
        seriesReleaseLookupProvider.overrideWithValue(
          mockSeriesReleaseByDropId,
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
