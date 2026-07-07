import 'dart:async';

import 'package:blindbox_app/features/collection/application/collection_notifier.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/recommendations/application/anonymous_id_provider.dart';
import 'package:blindbox_app/features/recommendations/data/preference_signal_extractor.dart';
import 'package:blindbox_app/features/recommendations/data/recommendation_gateway_config.dart';
import 'package:blindbox_app/features/recommendations/application/recommendations_provider.dart';
import 'package:blindbox_app/features/recommendations/data/recommendation_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final recommendationSyncProvider =
    NotifierProvider<RecommendationSyncNotifier, void>(
  RecommendationSyncNotifier.new,
);

class RecommendationSyncNotifier extends Notifier<void> {
  Timer? _debounce;
  String? _lastUploadedHash;

  @override
  void build() {
    ref.keepAlive();
    ref.listen<CollectionSnapshot>(collectionNotifierProvider, (_, next) {
      _scheduleSyncAfterDelay();
    });
    return;
  }

  void _scheduleSyncAfterDelay() {
    _debounce?.cancel();
    _debounce = Timer(RecommendationGatewayConfig.profileSyncDebounce, _sync);
  }

  Future<void> _sync() async {
    final snap = ref.read(collectionNotifierProvider);
    final signals = extractSignals(snap);
    if (signals.trackedCatalogSeriesCount == 0) return;
    if (signals.profileHash == _lastUploadedHash) return;

    final id = await ref.read(anonymousInstallIdProvider.future);
    await ref.read(recommendationRepositoryProvider).updateProfile(id, signals);
    _lastUploadedHash = signals.profileHash;
    ref.invalidate(recommendationsProvider);
  }
}
