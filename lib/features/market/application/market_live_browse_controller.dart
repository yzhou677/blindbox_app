import 'dart:async';

import 'package:blindbox_app/features/market/application/collectible_market_providers.dart';
import 'package:blindbox_app/features/market/application/market_browse_notifier.dart';
import 'package:blindbox_app/features/market/application/market_live_browse_install.dart';
import 'package:blindbox_app/features/market/application/market_live_browse_session.dart';
import 'package:blindbox_app/features/market/application/market_listings_providers.dart';
import 'package:blindbox_app/features/market/data/gateway/market_gateway_config.dart';
import 'package:blindbox_app/features/market/data/source/ebay_gateway_market_source.dart';
import 'package:blindbox_app/features/market/domain/market_browse_query.dart';
import 'package:blindbox_app/models/market_listing.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final marketLiveBrowseControllerProvider =
    NotifierProvider<MarketLiveBrowseController, MarketLiveBrowseState>(
  MarketLiveBrowseController.new,
);

/// Query-driven live browse orchestration — session, pagination, stale-while-revalidate.
class MarketLiveBrowseController extends Notifier<MarketLiveBrowseState> {
  final MarketLiveBrowseSession _session = MarketLiveBrowseSession();
  final EbayGatewayMarketSource _ebay = EbayGatewayMarketSource();
  String? _lastAppliedSignature;
  bool _initialScheduled = false;
  bool _applyQueryInFlight = false;
  bool _disposed = false;

  bool get _isActive => !_disposed;

  void _publishState() {
    if (_isActive) state = _session.state;
  }

  @override
  MarketLiveBrowseState build() {
    _disposed = false;
    ref.onDispose(() => _disposed = true);

    if (!MarketGatewayConfig.isActive) {
      return const MarketLiveBrowseState();
    }

    ref.listen(marketBrowseNotifierProvider, _onBrowseUiChanged);

    if (!_initialScheduled) {
      _initialScheduled = true;
      Future.microtask(() {
        if (!_isActive) return;
        final browse = ref.read(marketBrowseNotifierProvider);
        _applyQuery(_queryFromBrowse(browse), reason: 'bootstrap');
      });
    }

    return _session.state;
  }

  void _onBrowseUiChanged(MarketBrowseState? prev, MarketBrowseState next) {
    if (!MarketGatewayConfig.isActive) return;

    final prevQuery = prev != null ? _queryFromBrowse(prev) : null;
    final nextQuery = _queryFromBrowse(next);
    if (prevQuery?.signature == nextQuery.signature) return;

    final brandIpChanged = prev == null ||
        prev.brandId != next.brandId ||
        prev.ipId != next.ipId;
    final searchCommitted = next.searchResultsActive &&
        (prev?.searchResultsActive != true || prev?.query != next.query);
    final searchCleared =
        prev?.searchResultsActive == true && !next.searchResultsActive;

    if (brandIpChanged || searchCommitted || searchCleared) {
      _applyQuery(nextQuery, reason: 'filters');
    }
  }

  Future<void> refresh() async {
    if (!MarketGatewayConfig.isActive) return;
    final browse = ref.read(marketBrowseNotifierProvider);
    final query = marketBrowseQueryFromUi(browse);
    final batch = await _ebay.resolveCachedBatchFor(query);
    if (batch != null &&
        batch.isFresh(ttl: MarketGatewayConfig.cacheTtl) &&
        batch.listings.isNotEmpty) {
      return;
    }
    await _applyQuery(
      query,
      reason: 'refresh',
      revalidate: true,
    );
  }

  Future<void> loadMore() async {
    if (!MarketGatewayConfig.isActive || _session.state.isLoadingMore) return;
    if (!_session.state.hasMore) return;

    final generation = _session.state.generation;
    _session.markLoadingMore(generation: generation);
    _publishState();

    final baseQuery = _session.state.query;
    final page = await _ebay.fetchNextPage(baseQuery);
    if (generation != _session.state.generation || !_isActive) return;

    if (page.listings.isEmpty && !page.fromCache) {
      final err = EbayGatewayMarketSource.lastFetchError;
      if (err != null) {
        _session.applyError(
          generation: generation,
          message: err,
        );
        _publishState();
        return;
      }
    }

    _session.applyNextPage(
      generation: generation,
      listings: page.listings,
      nextCursor: page.nextCursor,
      hasMore: page.hasMore,
    );
    _publishState();
    await _commitInstall(
      _session.state.listings,
      query: _session.state.query,
      generation: generation,
    );
  }

  /// Identity enrich + aggregation — yield a frame before heavy sync work.
  Future<void> _commitInstall(
    List<MarketListing> listings, {
    required MarketBrowseQuery query,
    required int generation,
  }) async {
    if (generation != _session.state.generation) return;
    await Future<void>.delayed(Duration.zero);
    if (generation != _session.state.generation || !_isActive) return;
    installLiveBrowseListings(listings, query: query);
    _scheduleBrowseProviderRefresh();
  }

  /// Refresh browse-derived providers after session singletons update.
  ///
  /// Deferred to the next frame so async gateway work cannot invalidate during
  /// an in-flight provider build (avoids Riverpod re-entrancy exceptions).
  void _scheduleBrowseProviderRefresh() {
    if (!_isActive) return;
    SchedulerBinding.instance.scheduleFrameCallback((_) {
      if (!_isActive) return;
      ref.invalidate(marketBrowseListingsProvider);
      ref.invalidate(collectibleMarketSnapshotsProvider);
    });
  }

  Future<void> _applyQuery(
    MarketBrowseQuery query, {
    required String reason,
    bool revalidate = false,
  }) async {
    if (!MarketGatewayConfig.isActive) return;
    if (_applyQueryInFlight && !revalidate) return;
    if (!revalidate &&
        _lastAppliedSignature == query.signature &&
        _session.state.hasListings) {
      return;
    }

    _applyQueryInFlight = true;
    try {
      await _applyQueryInner(
        query,
        reason: reason,
        revalidate: revalidate,
      );
    } finally {
      _applyQueryInFlight = false;
    }
  }

  Future<void> _applyQueryInner(
    MarketBrowseQuery query, {
    required String reason,
    bool revalidate = false,
  }) async {
    if (!MarketGatewayConfig.isActive) return;

    final staleBatch = await _ebay.resolveCachedBatchFor(query);
    final staleListings = staleBatch?.listings;
    _session.resetForQuery(
      query,
      staleListings: staleListings,
      staleCursor: staleBatch?.nextCursor,
      staleHasMore: staleBatch?.hasMore ?? false,
    );
    _lastAppliedSignature = query.signature;

    final generation = _session.state.generation;

    if (staleListings != null && staleListings.isNotEmpty) {
      unawaited(
        _commitInstall(
          staleListings,
          query: query,
          generation: generation,
        ),
      );
    }

    if (revalidate || reason == 'refresh') {
      _session.markRefreshing(generation: generation);
    } else {
      _session.markLoadingInitial(generation: generation);
    }
    _publishState();

    final page = await _ebay.fetchFirstPage(query);
    if (generation != _session.state.generation || !_isActive) return;

    if (page.listings.isEmpty && !page.fromCache) {
      final err = EbayGatewayMarketSource.lastFetchError;
      if (err != null) {
        _session.applyError(
          generation: generation,
          message: err,
        );
        _publishState();
        return;
      }
    }

    _session.applyFirstPage(
      generation: generation,
      listings: page.listings,
      nextCursor: page.nextCursor,
      hasMore: page.hasMore,
      query: query,
      fromStaleCache: page.fromCache,
    );
    _publishState();
    await _commitInstall(
      page.listings,
      query: query,
      generation: generation,
    );
  }

  static MarketBrowseQuery _queryFromBrowse(MarketBrowseState browse) {
    return MarketBrowseQuery(
      brandId: browse.brandId,
      ipId: browse.ipId,
      searchText: browse.searchResultsActive ? browse.query.trim() : '',
      limit: MarketGatewayConfig.initialPageSize,
    );
  }
}

/// Bridges UI browse chips/search to upstream query facets.
MarketBrowseQuery marketBrowseQueryFromUi(MarketBrowseState browse) =>
    MarketLiveBrowseController._queryFromBrowse(browse);
