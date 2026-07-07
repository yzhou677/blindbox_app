import 'dart:async';

import 'package:blindbox_app/features/collection/application/collection_notifier.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/recommendations/data/preference_signal_extractor.dart';
import 'package:blindbox_app/features/recommendations/data/recommendation_gateway_config.dart';
import 'package:blindbox_app/features/recommendations/domain/recommendation_confidence.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final recommendationReadinessProvider =
    NotifierProvider<RecommendationReadinessNotifier, bool>(
  RecommendationReadinessNotifier.new,
);

final forYouFirstUnlockBadgeProvider = Provider<bool>((ref) {
  final ready = ref.watch(recommendationReadinessProvider);
  if (!ready) return false;
  return !ref.watch(_forYouFirstUnlockShownProvider);
});

final _forYouFirstUnlockShownProvider =
    NotifierProvider<_ForYouFirstUnlockShownNotifier, bool>(
  _ForYouFirstUnlockShownNotifier.new,
);

class RecommendationReadinessNotifier extends Notifier<bool> {
  bool _persistedUnlocked = false;
  bool _prefsLoaded = false;

  @override
  bool build() {
    unawaited(_loadPersistedUnlocked());
    ref.listen<CollectionSnapshot>(collectionNotifierProvider, (_, next) {
      _reevaluate(next);
    });
    return _evaluate(ref.read(collectionNotifierProvider));
  }

  Future<void> _loadPersistedUnlocked() async {
    if (_prefsLoaded) return;
    final prefs = await SharedPreferences.getInstance();
    _persistedUnlocked =
        prefs.getBool(RecommendationGatewayConfig.readinessUnlockedKey) ??
            false;
    _prefsLoaded = true;
    if (_persistedUnlocked && !state) {
      state = true;
      return;
    }
    _reevaluate(ref.read(collectionNotifierProvider));
  }

  void _reevaluate(CollectionSnapshot snap) {
    if (state) return;
    if (_persistedUnlocked) {
      state = true;
      return;
    }
    if (isRecommendationReady(extractSignals(snap))) {
      state = true;
      unawaited(_persistUnlocked());
    }
  }

  bool _evaluate(CollectionSnapshot snap) {
    if (_persistedUnlocked) return true;
    return isRecommendationReady(extractSignals(snap));
  }

  Future<void> _persistUnlocked() async {
    _persistedUnlocked = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(RecommendationGatewayConfig.readinessUnlockedKey, true);
  }
}

class _ForYouFirstUnlockShownNotifier extends Notifier<bool> {
  @override
  bool build() {
    unawaited(_load());
    return false;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final shown =
        prefs.getBool(RecommendationGatewayConfig.firstUnlockShownKey) ?? false;
    if (shown) {
      state = true;
    }
  }

  Future<void> markShown() async {
    if (state) return;
    state = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(RecommendationGatewayConfig.firstUnlockShownKey, true);
  }
}

/// Dismisses the one-time first-unlock badge.
void dismissForYouFirstUnlockBadge(WidgetRef ref) {
  ref.read(_forYouFirstUnlockShownProvider.notifier).markShown();
}

@visibleForTesting
Future<void> resetRecommendationReadinessPrefsForTest() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove(RecommendationGatewayConfig.readinessUnlockedKey);
  await prefs.remove(RecommendationGatewayConfig.firstUnlockShownKey);
}
