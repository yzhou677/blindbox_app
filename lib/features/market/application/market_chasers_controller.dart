import 'dart:async';

import 'package:blindbox_app/features/market/application/chasers_phase1_scorer.dart';
import 'package:blindbox_app/features/market/application/chasers_probe_targets.dart';
import 'package:blindbox_app/features/market/data/cache/market_chasers_cache.dart';
import 'package:blindbox_app/features/market/data/chasers/market_chasers_config.dart';
import 'package:blindbox_app/features/market/data/gateway/market_gateway_config.dart';
import 'package:blindbox_app/features/market/data/source/ebay_gateway_market_source.dart';
import 'package:blindbox_app/features/market/domain/chasers_heat_entry.dart';
import 'package:blindbox_app/features/market/domain/market_browse_query.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final marketChasersControllerProvider =
    NotifierProvider<MarketChasersController, MarketChasersState>(
  MarketChasersController.new,
);

@immutable
class MarketChasersState {
  const MarketChasersState({
    this.entries = const [],
    this.isLoading = false,
    this.lastRefreshedAt,
  });

  final List<ChasersHeatEntry> entries;
  final bool isLoading;
  final DateTime? lastRefreshedAt;

  bool get hasEntries => entries.isNotEmpty;
}

/// Probes IP-specific browse pages, clusters titles, and ranks Phase 1 chasers.
class MarketChasersController extends Notifier<MarketChasersState> {
  final EbayGatewayMarketSource _source = EbayGatewayMarketSource();
  final MarketChasersCache _cache = MarketChasersCache.instance;
  bool _refreshScheduled = false;
  bool _refreshInFlight = false;
  bool _hydratedFromDisk = false;

  @override
  MarketChasersState build() {
    ref.onDispose(() => _refreshScheduled = false);
    _hydrateFromMemoryCache();
    if (_shouldRun) {
      _scheduleRefreshIfStale();
    }
    return state;
  }

  bool get _shouldRun =>
      MarketChasersConfig.enablePhase1Scoring && MarketGatewayConfig.isActive;

  void _hydrateFromMemoryCache() {
    final batch = _cache.readMemory(allowExpired: true);
    if (batch == null || batch.entries.isEmpty) return;
    state = MarketChasersState(
      entries: batch.entries,
      isLoading: false,
      lastRefreshedAt: batch.fetchedAt,
    );
  }

  void _scheduleRefreshIfStale() {
    if (_refreshScheduled) return;
    _refreshScheduled = true;
    Future.microtask(() async {
      _refreshScheduled = false;
      if (!_shouldRun) return;
      if (!_hydratedFromDisk) {
        _hydratedFromDisk = true;
        final disk = await _cache.readFromDisk();
        if (disk != null &&
            disk.entries.isNotEmpty &&
            disk.isDiskStaleAcceptable()) {
          state = MarketChasersState(
            entries: disk.entries,
            isLoading: false,
            lastRefreshedAt: disk.fetchedAt,
          );
        }
      }
      await refreshIfStale();
    });
  }

  Future<void> refreshIfStale() async {
    if (!_shouldRun || _refreshInFlight) return;
    final last = state.lastRefreshedAt;
    if (last != null &&
        DateTime.now().difference(last) < MarketChasersConfig.memoryRefreshTtl) {
      return;
    }
    await refresh(force: true);
  }

  Future<void> refresh({bool force = false}) async {
    if (!_shouldRun) return;
    if (_refreshInFlight) return;
    if (!force &&
        state.lastRefreshedAt != null &&
        DateTime.now().difference(state.lastRefreshedAt!) <
            MarketChasersConfig.memoryRefreshTtl) {
      return;
    }

    _refreshInFlight = true;
    final showLoading = state.entries.isEmpty;
    if (showLoading) {
      state = state.copyWithLoading(true);
    }
    try {
      final targets = buildChasersProbeTargets()
          .take(MarketChasersConfig.maxProbesPerRefresh)
          .toList(growable: false);
      final collected = <ChasersHeatEntry>[];
      final concurrency = MarketChasersConfig.probeConcurrency.clamp(1, 4);

      for (var i = 0; i < targets.length; i += concurrency) {
        final batch = targets
            .skip(i)
            .take(concurrency)
            .toList(growable: false);
        final batchEntries = await Future.wait([
          for (final target in batch) _fetchProbeEntries(target),
        ]);
        for (final entries in batchEntries) {
          collected.addAll(entries);
        }
        _publishPartial(collected, loading: true);

        final hasMore = i + batch.length < targets.length;
        if (hasMore) {
          await Future<void>.delayed(MarketChasersConfig.probeDelay);
        }
      }

      final merged = mergeChaserEntries(collected)
          .take(MarketChasersConfig.maxRailEntries)
          .toList(growable: false);

      final refreshedAt = DateTime.now();
      state = MarketChasersState(
        entries: merged,
        isLoading: false,
        lastRefreshedAt: refreshedAt,
      );
      if (merged.isNotEmpty) {
        unawaited(_cache.write(merged));
      }
    } catch (e, st) {
      debugPrint('MarketChasersController refresh failed: $e\n$st');
      state = state.copyWithLoading(false);
    } finally {
      _refreshInFlight = false;
    }
  }

  Future<List<ChasersHeatEntry>> _fetchProbeEntries(
    ChasersProbeTarget target,
  ) async {
    final page = await _source.fetchFirstPage(
      MarketBrowseQuery(
        brandId: target.brandId,
        ipId: target.ipId,
        limit: MarketChasersConfig.probePageSize,
      ),
    );
    return buildChaserEntriesFromProbe(
      target: target,
      listings: page.listings,
    );
  }

  void _publishPartial(List<ChasersHeatEntry> collected, {required bool loading}) {
    if (!_refreshInFlight) return;
    final merged = mergeChaserEntries(collected)
        .take(MarketChasersConfig.maxRailEntries)
        .toList(growable: false);
    state = MarketChasersState(
      entries: merged,
      isLoading: loading,
      lastRefreshedAt: state.lastRefreshedAt,
    );
  }
}

extension on MarketChasersState {
  MarketChasersState copyWithLoading(bool isLoading) {
    return MarketChasersState(
      entries: entries,
      isLoading: isLoading,
      lastRefreshedAt: lastRefreshedAt,
    );
  }
}
