import 'package:blindbox_app/features/catalog/application/catalog_bundle_cache.dart';
import 'package:blindbox_app/features/catalog/application/catalog_bundle_provider.dart';
import 'package:blindbox_app/features/catalog/catalog_seed_loader.dart';
import 'package:blindbox_app/features/collection/data/series_release_lookup.dart';
import 'package:blindbox_app/features/home/data/catalog_series_release_builder.dart';
import 'package:blindbox_app/features/home/data/home_feed_picker.dart';
import 'package:blindbox_app/features/home/data/mock_latest_drops.dart';
import 'package:blindbox_app/features/home/domain/series_release.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Built Latest + Trending rails for Discover.
@immutable
class HomeFeedSnapshot {
  const HomeFeedSnapshot({
    required this.latest,
    required this.trending,
  });

  final List<SeriesRelease> latest;
  final List<SeriesRelease> trending;

  SeriesRelease? releaseByDropId(String dropId) {
    for (final r in latest) {
      if (r.dropId == dropId) return r;
    }
    for (final r in trending) {
      if (r.dropId == dropId) return r;
    }
    return null;
  }
}

HomeFeedSnapshot _emptyHomeFeedSnapshot() => const HomeFeedSnapshot(
      latest: [],
      trending: [],
    );

final homeFeedSnapshotProvider = FutureProvider<HomeFeedSnapshot>((ref) async {
  try {
    final CatalogSeedBundle bundle;
    final cached = CatalogBundleCache.current;
    if (cached != null) {
      bundle = cached;
    } else {
      bundle = await ref.watch(catalogBundleProvider.future);
    }
    final pick = pickHomeFeedSeries(bundle);
    final latest = await buildSeriesReleasesFromCatalog(bundle, pick.latest);
    final trending = await buildSeriesReleasesFromCatalog(bundle, pick.trending);

    if (latest.isEmpty && trending.isEmpty) {
      return _emptyHomeFeedSnapshot();
    }

    return HomeFeedSnapshot(
      latest: latest,
      trending: trending,
    );
  } catch (_) {
    return _emptyHomeFeedSnapshot();
  }
});

/// Catalog-backed drops with mock fallback for legacy ids / tests.
final homeSeriesReleaseLookupProvider = Provider<SeriesReleaseLookup>((ref) {
  final feed = ref.watch(homeFeedSnapshotProvider).valueOrNull;
  return (dropId) => feed?.releaseByDropId(dropId) ?? mockSeriesReleaseByDropId(dropId);
});
