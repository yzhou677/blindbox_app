import 'dart:convert';

import 'package:blindbox_app/features/catalog/catalog_bundle.dart';
import 'package:blindbox_app/features/collection/application/collection_notifier.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/recommendations/data/preference_signal_extractor.dart';
import 'package:blindbox_app/features/recommendations/data/recommendation_gateway_config.dart';
import 'package:blindbox_app/features/recommendations/data/recommendation_http_client.dart';
import 'package:blindbox_app/features/recommendations/data/recommendation_rule_engine.dart';
import 'package:blindbox_app/features/recommendations/domain/recommendation_item.dart';
import 'package:blindbox_app/features/recommendations/domain/recommendation_result.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final recommendationRepositoryProvider = Provider<RecommendationRepository>((ref) {
  final snap = ref.watch(collectionNotifierProvider);
  return RecommendationRepository(
    collectionSnapshot: snap,
    httpClient: RecommendationHttpClient(),
  );
});

class _ComputedRecommendationMemo {
  const _ComputedRecommendationMemo({
    required this.installId,
    required this.profileHash,
    required this.result,
  });

  final String installId;
  final String profileHash;
  final RecommendationResult result;
}

class RecommendationRepository {
  /// Session memo intentionally keeps a single entry to remain lightweight.
  static _ComputedRecommendationMemo? _lastComputed;

  @visibleForTesting
  static void resetComputedMemoForTest() {
    _lastComputed = null;
  }

  RecommendationRepository({
    required CollectionSnapshot collectionSnapshot,
    RecommendationHttpClient? httpClient,
    SharedPreferences? preferences,
  })  : _collectionSnapshot = collectionSnapshot,
        _httpClient = httpClient ?? RecommendationHttpClient(),
        _preferences = preferences;

  final CollectionSnapshot _collectionSnapshot;
  final RecommendationHttpClient _httpClient;
  SharedPreferences? _preferences;

  Future<SharedPreferences> _prefs() async {
    return _preferences ??= await SharedPreferences.getInstance();
  }

  String _cacheKey(String installId) => 'reco_cache_v2_$installId';

  PreferenceSignals _signals() => extractSignals(_collectionSnapshot);

  Future<RecommendationResult> getRecommendations(
    String installId,
    CatalogSeedBundle bundle,
  ) async {
    try {
      return await _getRecommendationsUnsafe(installId, bundle);
    } catch (_) {
      return const RecommendationResult(items: []);
    }
  }

  Future<RecommendationResult> _getRecommendationsUnsafe(
    String installId,
    CatalogSeedBundle bundle,
  ) async {
    final signals = _signals();
    final memo = _lastComputed;
    if (memo != null &&
        memo.installId == installId &&
        memo.profileHash == signals.profileHash) {
      return _finalizeResult(
        installId: installId,
        signals: signals,
        result: memo.result,
        bundle: bundle,
        remember: false,
      );
    }

    final cached = await _readCache(installId, signals.profileHash);
    if (cached != null) {
      return _finalizeResult(
        installId: installId,
        signals: signals,
        result: cached,
        bundle: bundle,
      );
    }

    if (RecommendationGatewayConfig.isHttpActive) {
      try {
        final remote = await _httpClient.fetchForYou(
          baseUrl: RecommendationGatewayConfig.gatewayUri!,
          installId: installId,
        );
        final normalized = excludeTrackedCatalogSeries(
          _normalizeResult(remote),
          signals,
        );
        if (normalized.items.isNotEmpty &&
            _isResultForCurrentProfile(signals, normalized)) {
          await _writeCache(installId, normalized);
          return _finalizeResult(
            installId: installId,
            signals: signals,
            result: normalized,
            bundle: bundle,
          );
        }
      } catch (_) {
        // Fall through to local engine.
      }
    }

    final local = _safeComputeLocal(bundle, signals);
    if (local.items.isNotEmpty) {
      await _writeCache(installId, local);
    }
    return _finalizeResult(
      installId: installId,
      signals: signals,
      result: local,
      bundle: bundle,
    );
  }

  RecommendationResult _safeComputeLocal(
    CatalogSeedBundle bundle,
    PreferenceSignals signals,
  ) {
    try {
      return _normalizeResult(_computeLocal(bundle, signals));
    } catch (_) {
      return const RecommendationResult(items: []);
    }
  }

  Future<void> updateProfile(
    String installId,
    PreferenceSignals signals,
  ) async {
    if (signals.trackedCatalogSeriesCount == 0) return;
    if (!RecommendationGatewayConfig.isHttpActive) return;

    try {
      await _httpClient.updateProfile(
        baseUrl: RecommendationGatewayConfig.gatewayUri!,
        installId: installId,
        signals: signals,
      );
      await invalidateRecommendationCache(installId);
    } catch (_) {
      // Best-effort cloud sync; local engine remains authoritative offline.
    }
  }

  Future<void> invalidateRecommendationCache(String installId) async {
    if (_lastComputed?.installId == installId) {
      _lastComputed = null;
    }
    try {
      final prefs = await _prefs();
      await prefs.remove(_cacheKey(installId));
    } catch (_) {
      // In-memory memo already cleared.
    }
  }

  RecommendationResult _finalizeResult({
    required String installId,
    required PreferenceSignals signals,
    required RecommendationResult result,
    required CatalogSeedBundle bundle,
    bool remember = true,
  }) {
    try {
      final sanitized =
          excludeTrackedCatalogSeries(_normalizeResult(result), signals);
      if (remember) {
        _lastComputed = _ComputedRecommendationMemo(
          installId: installId,
          profileHash: signals.profileHash,
          result: sanitized,
        );
      }
      return _resolveSeries(sanitized, bundle);
    } catch (_) {
      return const RecommendationResult(items: []);
    }
  }

  /// True when [result] was computed for the current shelf taste profile.
  bool _isResultForCurrentProfile(
    PreferenceSignals signals,
    RecommendationResult result,
  ) {
    final hash = result.profileHash?.trim();
    if (hash == null || hash.isEmpty || hash != signals.profileHash) {
      return false;
    }
    for (final item in result.items) {
      if (signals.trackedCatalogSeriesIds.contains(item.seriesId)) {
        return false;
      }
    }
    return true;
  }

  RecommendationResult _computeLocal(
    CatalogSeedBundle bundle,
    PreferenceSignals signals,
  ) {
    final items = computeLocalRecommendations(
      signals: signals,
      bundle: bundle,
    );
    return RecommendationResult(
      items: items,
      profileHash: signals.profileHash,
    );
  }

  Future<RecommendationResult?> _readCache(
    String installId,
    String currentProfileHash,
  ) async {
    try {
      // Cache validity: schemaVersion + profileHash only — not age.
      final prefs = await _prefs();
      final raw = prefs.getString(_cacheKey(installId));
      if (raw == null || raw.isEmpty) return null;

      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      final schemaVersion = decoded['schemaVersion'];
      if (schemaVersion != RecommendationGatewayConfig.recommendationCacheSchemaVersion) {
        return null;
      }
      final cachedHash = decoded['profileHash'] as String?;
      if (cachedHash == null || cachedHash != currentProfileHash) {
        return null;
      }
      final result = RecommendationResult.fromJson(decoded);
      if (result.items.isEmpty) {
        return null;
      }
      if (result.items.length > RecommendationGatewayConfig.forYouResultLimit) {
        return null;
      }
      return result;
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeCache(String installId, RecommendationResult result) async {
    try {
      final prefs = await _prefs();
      await prefs.setString(
        _cacheKey(installId),
        jsonEncode({
          'schemaVersion':
              RecommendationGatewayConfig.recommendationCacheSchemaVersion,
          ...result.toJson(),
        }),
      );
    } catch (_) {
      // Cache is optional; recommendations still return in-memory.
    }
  }

  RecommendationResult _normalizeResult(RecommendationResult result) {
    final limit = RecommendationGatewayConfig.forYouResultLimit;
    if (result.items.length <= limit) return result;
    return RecommendationResult(
      items: result.items.take(limit).toList(),
      profileHash: result.profileHash,
    );
  }

  RecommendationResult _resolveSeries(
    RecommendationResult result,
    CatalogSeedBundle bundle,
  ) {
    final byId = {for (final series in bundle.series) series.id: series};
    final resolved = <RecommendationItem>[];
    for (final item in result.items) {
      final series = byId[item.seriesId];
      if (series == null) continue;
      resolved.add(item.copyWith(series: series));
    }
    return RecommendationResult(
      items: resolved,
      profileHash: result.profileHash,
    );
  }
}

/// Defensive pass — tracked catalog series must never reach For You UI.
RecommendationResult excludeTrackedCatalogSeries(
  RecommendationResult result,
  PreferenceSignals signals,
) {
  if (signals.trackedCatalogSeriesIds.isEmpty) return result;
  final filtered = result.items
      .where((item) => !signals.trackedCatalogSeriesIds.contains(item.seriesId))
      .toList();
  if (filtered.length == result.items.length) return result;
  return RecommendationResult(
    items: filtered,
    profileHash: result.profileHash,
  );
}
