import 'dart:async';

import 'package:blindbox_app/features/catalog/application/catalog_bundle_cache.dart';
import 'package:blindbox_app/features/home/application/home_feed_provider.dart';
import 'package:blindbox_app/features/ip_profile/application/ip_profile_providers.dart';
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
      // Soft-invalidate IP profiles (no N-read storm). Active detail watchers
      // revalidate via epoch; others stay lazy until remounted.
      ref.read(ipProfileRepositoryProvider).prepareForRevalidation();
      ref.read(ipProfileRevalidationEpochProvider.notifier).state++;

      unawaited(
        CatalogBundleCache.refreshFromFirestore().then((outcome) {
          if (outcome == CatalogFirestoreRefreshResult.failed) {
            ref.invalidate(homeFeedSnapshotProvider);
          }
        }),
      );
      final _ = await ref.refresh(officialFeedCatalogProvider.future);
    } finally {
      // Discover may dispose mid-await; never write after teardown.
      try {
        state = false;
      } catch (_) {}
    }
  }
}
