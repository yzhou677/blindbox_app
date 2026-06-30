import 'dart:async';

import 'package:blindbox_app/core/theme/app_theme.dart';
import 'package:blindbox_app/features/catalog/application/catalog_availability.dart';
import 'package:blindbox_app/features/catalog/application/catalog_bundle_cache.dart';
import 'package:blindbox_app/features/catalog/application/catalog_bundle_provider.dart';
import 'package:blindbox_app/features/catalog/catalog_bundle.dart';
import 'package:blindbox_app/features/catalog/presentation/catalog_availability_copy.dart';
import 'package:blindbox_app/features/catalog/presentation/catalog_browse_screen.dart';
import 'package:blindbox_app/features/catalog/models/catalog_brand.dart';
import 'package:blindbox_app/features/catalog/models/catalog_ip.dart';
import 'package:blindbox_app/features/catalog/models/catalog_series.dart';
import 'package:blindbox_app/features/home/application/catalog_bundle_refresh_bridge.dart';
import 'package:blindbox_app/features/home/application/home_feed_provider.dart';
import 'package:blindbox_app/features/home/domain/series_release.dart';
import 'package:blindbox_app/features/home/home_screen.dart';
import 'package:blindbox_app/features/home/presentation/latest_drops_copy.dart';
import 'package:blindbox_app/features/official_feed/application/official_feed_providers.dart';
import 'package:blindbox_app/features/official_feed/domain/official_feed_item.dart';
import 'package:blindbox_app/features/official_feed/presentation/official_feed_copy.dart';
import 'package:blindbox_app/models/collectible.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

CatalogSeedBundle _bundle({String seriesId = 'home_series'}) => CatalogSeedBundle(
      brands: const [CatalogBrand(id: 'b', displayName: 'B')],
      ips: const [CatalogIp(id: 'ip', brandId: 'b', displayName: 'IP')],
      series: [
        CatalogSeries(
          id: seriesId,
          brandId: 'b',
          ipId: 'ip',
          displayName: seriesId,
          releaseDate: '2026-05-12',
          isBlindBox: true,
          imageKey: seriesId,
        ),
      ],
      figures: const [],
    );

SeriesRelease _homeRelease({String seriesName = 'Home Series'}) => SeriesRelease(
      dropId: 'home_series',
      seriesName: seriesName,
      brand: 'B',
      releaseDate: DateTime(2026, 5, 12),
      seriesImageKey: 'home_series',
      heroCollectible: Collectible(
        id: 'home_series',
        name: seriesName,
        series: seriesName,
        brand: 'B',
        releaseDate: DateTime(2026, 5, 12),
        imageUrl: '',
      ),
      lineup: const [
        ReleaseLineupSlot(
          slotId: 'slot_1',
          name: 'Figure',
          imageKey: 'home_series',
          isSecret: false,
        ),
      ],
    );

final _officialFeedSample = [
  OfficialFeedItem(
    id: 'official_1',
    sourceId: 'pm',
    sourceLabel: 'POP MART',
    title: 'Spring drop preview',
    imageUrl: 'https://example.com/feed.png',
    officialUrl: 'https://example.com/post',
    publishedAt: DateTime(2026, 3, 1),
    contentHash: 'hash_1',
  ),
];

Widget _homeHarness(ProviderContainer container) {
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      theme: AppTheme.light(),
      home: const CatalogBundleRefreshBridge(child: HomeScreen()),
    ),
  );
}

Widget _catalogBrowseHarness(ProviderContainer container) {
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      theme: AppTheme.light(),
      home: const CatalogBrowseScreen(),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    CatalogBundleCache.resetForTest();
  });

  tearDown(CatalogBundleCache.resetForTest);

  testWidgets('Discover shows loading card while catalog is downloading', (tester) async {
    final bundleGate = Completer<CatalogSeedBundle>();
    final container = ProviderContainer(
      overrides: [
        officialFeedListProvider.overrideWith((ref) async => _officialFeedSample),
        homeFeedSnapshotProvider.overrideWith((ref) async {
          return const HomeFeedSnapshot(latest: [], trending: []);
        }),
        catalogBundleProvider.overrideWith((ref) => bundleGate.future),
      ],
    );
    addTearDown(container.dispose);

    CatalogBundleCache.primeBootstrapPlaceholderForTest();
    container.read(catalogBundleRevisionProvider);

    await tester.pumpWidget(_homeHarness(container));
    await tester.pump();

    expect(find.text(LatestDropsCopy.sectionTitle), findsOneWidget);
    expect(find.text(CatalogAvailabilityCopy.loadingTitle), findsWidgets);
    expect(find.text(OfficialFeedCopy.sectionTitle), findsOneWidget);

    bundleGate.complete(_bundle());
  });

  testWidgets('Discover shows offline retry when catalog resolved empty', (tester) async {
    final container = ProviderContainer(
      overrides: [
        officialFeedListProvider.overrideWith((ref) async => _officialFeedSample),
        homeFeedSnapshotProvider.overrideWith((ref) async {
          return const HomeFeedSnapshot(latest: [], trending: []);
        }),
      ],
    );
    addTearDown(container.dispose);

    CatalogBundleCache.loadPersistedOverride = () async => null;
    CatalogBundleCache.loadFirestoreOverride = () async {
      throw StateError('offline');
    };

    await CatalogBundleCache.loadOfflineFirst();
    await CatalogBundleCache.refreshFromFirestore(force: true);
    container.read(catalogBundleRevisionProvider);
    await container.read(catalogBundleProvider.future);

    await tester.pumpWidget(_homeHarness(container));
    await tester.pump();

    expect(find.text(CatalogAvailabilityCopy.offlineBody), findsWidgets);
    expect(find.text(CatalogAvailabilityCopy.retryLabel), findsWidgets);
    expect(find.text(OfficialFeedCopy.sectionTitle), findsOneWidget);
  });

  testWidgets('Discover shows catalog rails when ready', (tester) async {
    final container = ProviderContainer(
      overrides: [
        officialFeedListProvider.overrideWith((ref) async => []),
        homeFeedSnapshotProvider.overrideWith((ref) async {
          return HomeFeedSnapshot(
            latest: [_homeRelease()],
            trending: const [],
          );
        }),
      ],
    );
    addTearDown(container.dispose);

    CatalogBundleCache.prime(_bundle());
    container.read(catalogBundleRevisionProvider);
    await container.read(catalogBundleProvider.future);

    await tester.pumpWidget(_homeHarness(container));
    await tester.pump();

    expect(find.text(LatestDropsCopy.sectionTitle), findsOneWidget);
    expect(find.text('Home Series'), findsOneWidget);
    expect(find.text(CatalogAvailabilityCopy.loadingTitle), findsNothing);
  });

  testWidgets('Catalog search shows downloading message instead of no matches', (tester) async {
    final bundleGate = Completer<CatalogSeedBundle>();
    final container = ProviderContainer(
      overrides: [
        catalogBundleProvider.overrideWith((ref) => bundleGate.future),
      ],
    );
    addTearDown(container.dispose);

    CatalogBundleCache.primeBootstrapPlaceholderForTest();
    container.read(catalogBundleRevisionProvider);

    await tester.pumpWidget(_catalogBrowseHarness(container));
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'labubu');
    await tester.pump();

    expect(find.text(CatalogAvailabilityCopy.searchStillDownloading), findsOneWidget);
    expect(find.text('No matches for that search.'), findsNothing);

    bundleGate.complete(_bundle());
  });

  testWidgets('Discover keeps catalog rails without downloading banner while refreshing',
      (tester) async {
    final refreshGate = Completer<CatalogSeedBundle>();
    final container = ProviderContainer(
      overrides: [
        officialFeedListProvider.overrideWith((ref) async => []),
        homeFeedSnapshotProvider.overrideWith((ref) async {
          return HomeFeedSnapshot(
            latest: [_homeRelease()],
            trending: const [],
          );
        }),
      ],
    );
    addTearDown(container.dispose);

    CatalogBundleCache.prime(_bundle());
    CatalogBundleCache.loadFirestoreOverride = () => refreshGate.future;
    container.read(catalogBundleRevisionProvider);
    await container.read(catalogBundleProvider.future);
    unawaited(CatalogBundleCache.refreshFromFirestore(force: true));

    await tester.pumpWidget(_homeHarness(container));
    await tester.pump();

    expect(find.text(LatestDropsCopy.sectionTitle), findsOneWidget);
    expect(find.text('Home Series'), findsOneWidget);
    expect(find.text(CatalogAvailabilityCopy.loadingTitle), findsNothing);

    refreshGate.complete(_bundle(seriesId: 'fresh'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text(CatalogAvailabilityCopy.loadingTitle), findsNothing);
  });
}
