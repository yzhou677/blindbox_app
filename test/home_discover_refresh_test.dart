import 'package:blindbox_app/features/catalog/application/catalog_bundle_cache.dart';
import 'package:blindbox_app/features/catalog/catalog_bundle.dart';
import 'package:blindbox_app/features/home/application/home_discover_refresh_controller.dart';
import 'package:blindbox_app/features/home/application/home_feed_provider.dart';
import 'package:blindbox_app/features/ip_profile/application/ip_profile_providers.dart';
import 'package:blindbox_app/features/ip_profile/data/ip_profile_repository.dart';
import 'package:blindbox_app/features/ip_profile/domain/ip_introduction_profile.dart';
import 'package:blindbox_app/features/official_feed/application/official_feed_providers.dart';
import 'package:blindbox_app/features/official_feed/domain/official_feed_catalog.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(CatalogBundleCache.resetForTest);

  setUp(() {
    CatalogBundleCache.persistOverride = (_) async {};
  });

  test(
    'homeDiscoverRefreshProvider reloads official feed without awaiting catalog',
    () async {
      var catalogRefreshCount = 0;
      var officialFeedLoadCount = 0;

      CatalogBundleCache.prime(
        const CatalogSeedBundle(brands: [], ips: [], series: [], figures: []),
      );
      CatalogBundleCache.loadFirestoreOverride = () async {
        catalogRefreshCount++;
        await Future<void>.delayed(const Duration(milliseconds: 200));
        return const CatalogSeedBundle(
          brands: [],
          ips: [],
          series: [],
          figures: [],
        );
      };

      final container = ProviderContainer(
        overrides: [
          officialFeedCatalogProvider.overrideWith((ref) async {
            officialFeedLoadCount++;
            return OfficialFeedCatalog.empty;
          }),
          ipProfileRepositoryProvider.overrideWithValue(
            MemoryIpProfileRepository(),
          ),
        ],
      );
      addTearDown(container.dispose);

      final stopwatch = Stopwatch()..start();
      await container.read(homeDiscoverRefreshProvider.notifier).refresh();
      stopwatch.stop();

      expect(stopwatch.elapsed, lessThan(const Duration(milliseconds: 150)));
      expect(officialFeedLoadCount, 1);
      expect(container.read(homeDiscoverRefreshProvider), isFalse);

      await Future<void>.delayed(const Duration(milliseconds: 250));
      expect(catalogRefreshCount, 1);
    },
  );

  test(
    'homeDiscoverRefreshProvider skips catalog when meta unchanged but reloads official feed',
    () async {
      var catalogRefreshCount = 0;
      var officialFeedLoadCount = 0;
      final lastSync = DateTime.now().toUtc();

      CatalogBundleCache.prime(
        const CatalogSeedBundle(brands: [], ips: [], series: [], figures: []),
      );
      CatalogBundleCache.setLastFirestoreRefreshAtForTest(lastSync);
      CatalogBundleCache.setLastSyncAtMemoryForTest(lastSync);
      CatalogBundleCache.loadMetaOverride = () async => lastSync;
      CatalogBundleCache.loadDeltaOverride = (_) async {
        fail('delta should not run when meta is unchanged');
      };
      CatalogBundleCache.loadFirestoreOverride = () async {
        catalogRefreshCount++;
        return const CatalogSeedBundle(
          brands: [],
          ips: [],
          series: [],
          figures: [],
        );
      };

      final container = ProviderContainer(
        overrides: [
          officialFeedCatalogProvider.overrideWith((ref) async {
            officialFeedLoadCount++;
            return OfficialFeedCatalog.empty;
          }),
          ipProfileRepositoryProvider.overrideWithValue(
            MemoryIpProfileRepository(),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(homeDiscoverRefreshProvider.notifier).refresh();

      expect(catalogRefreshCount, 0);
      expect(officialFeedLoadCount, 1);
    },
  );

  test(
    'homeDiscoverRefreshProvider invalidates home feed only when catalog fails',
    () async {
      var homeFeedLoadCount = 0;

      CatalogBundleCache.prime(
        const CatalogSeedBundle(brands: [], ips: [], series: [], figures: []),
      );
      CatalogBundleCache.loadFirestoreOverride = () async {
        throw StateError('network down');
      };

      final container = ProviderContainer(
        overrides: [
          officialFeedCatalogProvider.overrideWith(
            (_) async => OfficialFeedCatalog.empty,
          ),
          homeFeedSnapshotProvider.overrideWith((ref) async {
            homeFeedLoadCount++;
            return const HomeFeedSnapshot(latest: [], trending: []);
          }),
          ipProfileRepositoryProvider.overrideWithValue(
            MemoryIpProfileRepository(),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(homeDiscoverRefreshProvider.notifier).refresh();
      await pumpEventQueue();

      expect(homeFeedLoadCount, 1);
    },
  );

  test(
    'homeDiscoverRefreshProvider ignores overlapping refresh calls',
    () async {
      var catalogRefreshCount = 0;

      CatalogBundleCache.prime(
        const CatalogSeedBundle(brands: [], ips: [], series: [], figures: []),
      );
      CatalogBundleCache.loadFirestoreOverride = () async {
        catalogRefreshCount++;
        await Future<void>.delayed(const Duration(milliseconds: 50));
        return const CatalogSeedBundle(
          brands: [],
          ips: [],
          series: [],
          figures: [],
        );
      };

      final container = ProviderContainer(
        overrides: [
          officialFeedCatalogProvider.overrideWith(
            (_) async => OfficialFeedCatalog.empty,
          ),
          ipProfileRepositoryProvider.overrideWithValue(
            MemoryIpProfileRepository(),
          ),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(homeDiscoverRefreshProvider.notifier);
      final first = notifier.refresh();
      final second = notifier.refresh();

      await Future.wait([first, second]);
      await pumpEventQueue();

      expect(catalogRefreshCount, 1);
      expect(container.read(homeDiscoverRefreshProvider), isFalse);
    },
  );

  test(
    'Discover pull-to-refresh prepares IP revalidation without eager fetches',
    () async {
      final repo = MemoryIpProfileRepository({
        'molly': const IpIntroductionProfile(
          ipId: 'molly',
          displayName: 'MOLLY',
          shortDescription: 'Desc',
          styleTags: ['A', 'B', 'C'],
        ),
        'hirono': const IpIntroductionProfile(
          ipId: 'hirono',
          displayName: 'Hirono',
          shortDescription: 'Desc',
          styleTags: ['A', 'B', 'C'],
        ),
      });

      CatalogBundleCache.prime(
        const CatalogSeedBundle(brands: [], ips: [], series: [], figures: []),
      );
      CatalogBundleCache.loadFirestoreOverride = () async =>
          const CatalogSeedBundle(brands: [], ips: [], series: [], figures: []);

      final container = ProviderContainer(
        overrides: [
          officialFeedCatalogProvider.overrideWith(
            (_) async => OfficialFeedCatalog.empty,
          ),
          ipProfileRepositoryProvider.overrideWithValue(repo),
        ],
      );
      addTearDown(container.dispose);

      final before = container.read(ipProfileRevalidationEpochProvider);
      await container.read(homeDiscoverRefreshProvider.notifier).refresh();

      expect(repo.debugRevalidatePending, isTrue);
      expect(container.read(ipProfileRevalidationEpochProvider), before + 1);
      // Memory repo is not auto-fetched for every cached IP.
      expect(repo.requestedIds, isEmpty);
    },
  );
}
