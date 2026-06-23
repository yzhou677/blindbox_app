import 'dart:async';

import 'package:blindbox_app/features/catalog/application/catalog_bundle_cache.dart';
import 'package:blindbox_app/features/home/application/home_feed_provider.dart';
import 'package:blindbox_app/features/official_feed/application/official_feed_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final homeDiscoverRefreshProvider =
    NotifierProvider<HomeDiscoverRefreshNotifier, bool>(
  HomeDiscoverRefreshNotifier.new,
);

/// `true` while a manual Discover pull-to-refresh is in flight.
class HomeDiscoverRefreshNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  Future<void> refresh() async {
    if (state) return;
    state = true;
    try {
      unawaited(
        CatalogBundleCache.refreshFromFirestore().then((outcome) {
          if (outcome == CatalogFirestoreRefreshResult.failed) {
            ref.invalidate(homeFeedSnapshotProvider);
          }
        }),
      );
      final _ = await ref.refresh(officialFeedListProvider.future);
    } finally {
      state = false;
    }
  }
}
