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
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final recommendationRepositoryProvider = Provider<RecommendationRepository>((ref) {
  final snap = ref.watch(collectionNotifierProvider);
  return RecommendationRepository(
    collectionSnapshot: snap,
    httpClient: RecommendationHttpClient(),
  );
});

class RecommendationRepository {
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

  String _cacheKey(String installId) => 'reco_cache_v1_$installId';

  Future<RecommendationResult> getRecommendations(
    String installId,
    CatalogSeedBundle bundle,
  ) async {
    final cached = await _readCache(installId);
    if (cached != null) {
      return _resolveSeries(cached, bundle);
    }

    if (RecommendationGatewayConfig.isHttpActive) {
      try {
        final remote = await _httpClient.fetchForYou(
          baseUrl: RecommendationGatewayConfig.gatewayUri!,
          installId: installId,
        );
        if (remote.items.isNotEmpty) {
          await _writeCache(installId, remote);
          return _resolveSeries(remote, bundle);
        }
        // Empty remote is transient (profile not synced yet, etc.) — local fallback.
      } catch (_) {
        // Fall through to local engine.
      }
    }

    final local = _computeLocal(bundle);
    if (local.items.isNotEmpty) {
      await _writeCache(installId, local);
    }
    return _resolveSeries(local, bundle);
  }

  Future<void> updateProfile(
    String installId,
    PreferenceSignals signals,
  ) async {
    if (signals.ownedCatalogSeriesCount == 0) return;
    if (!RecommendationGatewayConfig.isHttpActive) return;

    await _httpClient.updateProfile(
      baseUrl: RecommendationGatewayConfig.gatewayUri!,
      installId: installId,
      signals: signals,
    );
    await invalidateRecommendationCache(installId);
  }

  Future<void> invalidateRecommendationCache(String installId) async {
    final prefs = await _prefs();
    await prefs.remove(_cacheKey(installId));
  }

  RecommendationResult _computeLocal(CatalogSeedBundle bundle) {
    final signals = extractSignals(_collectionSnapshot);
    final items = computeLocalRecommendations(
      signals: signals,
      bundle: bundle,
    );
    return RecommendationResult(items: items, fetchedAt: DateTime.now());
  }

  Future<RecommendationResult?> _readCache(String installId) async {
    final prefs = await _prefs();
    final raw = prefs.getString(_cacheKey(installId));
    if (raw == null || raw.isEmpty) return null;

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      final result = RecommendationResult.fromJson(decoded);
      if (result.items.isEmpty) return null;
      final age = DateTime.now().difference(result.fetchedAt);
      if (age > RecommendationGatewayConfig.cacheTTL) return null;
      return result;
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeCache(String installId, RecommendationResult result) async {
    final prefs = await _prefs();
    await prefs.setString(_cacheKey(installId), jsonEncode(result.toJson()));
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
    return RecommendationResult(items: resolved, fetchedAt: result.fetchedAt);
  }
}
