import 'dart:async';

import 'package:blindbox_app/features/market/application/collectible_market_providers.dart';
import 'package:blindbox_app/features/market/application/market_browse_notifier.dart';
import 'package:blindbox_app/features/market/application/market_live_browse_install.dart';
import 'package:blindbox_app/features/market/application/market_live_browse_session.dart';
import 'package:blindbox_app/features/market/application/market_listings_providers.dart';
import 'package:blindbox_app/features/market/debug/market_search_trace.dart';
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
///
/// Latest filter selection always wins: each query bumps [MarketLiveBrowseState.generation]
/// synchronously before any await; older network/cache commits are discarded.
class MarketLiveBrowseController extends Notifier<MarketLiveBrowseState> {
  final MarketLiveBrowseSession _session = MarketLiveBrowseSession();
  final EbayGatewayMarketSource _ebay = EbayGatewayMarketSource();
  String? _lastHandoffSignature;
  bool _initialScheduled = false;
  bool _disposed = false;

  bool get _isActive => !_disposed;

  void _publishState() {
    if (_isActive) {
      MarketSearchTrace.event(
        'liveBrowse._publishState gen=${_session.state.generation} '
        'loading=${_session.state.isLoadingInitial} '
        'rows=${_session.state.listings.length}',
        signature: _session.state.querySignature,
      );
      state = _session.state;
    }
  }

  /// True when [generation] still owns the active query handoff.
  bool _ownsGeneration(int generation, MarketBrowseQuery query) {
    return _isActive &&
        generation == _session.state.generation &&
        query.signature == _session.state.querySignature;
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
        _startQuery(_queryFromBrowse(browse), reason: 'bootstrap');
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
      MarketSearchTrace.event(
        '_onBrowseUiChanged → _startQuery',
        signature: nextQuery.signature,
      );
      _startQuery(nextQuery, reason: 'filters');
    }
  }

  /// Synchronous handoff — bumps generation before any await so latest filters win.
  int? _handoffQuery(
    MarketBrowseQuery query, {
    required String reason,
    bool revalidate = false,
  }) {
    if (!MarketGatewayConfig.isActive) return null;
    if (!revalidate &&
        _lastHandoffSignature == query.signature &&
        _session.state.isBusy &&
        _session.state.querySignature == query.signature) {
      return null;
    }

    final memoryBatch = _ebay.cachedBatchFor(query);
    final generation = _session.resetForQuery(
      query,
      staleListings: memoryBatch?.listings,
      staleCursor: memoryBatch?.nextCursor,
      staleHasMore: memoryBatch?.hasMore ?? false,
    );
    _lastHandoffSignature = query.signature;

    if (revalidate || reason == 'refresh') {
      _session.markRefreshing(generation: generation);
    } else {
      _session.markLoadingInitial(generation: generation);
    }
    _publishState();

    if (memoryBatch != null && memoryBatch.listings.isNotEmpty) {
      MarketSearchTrace.event(
        '_handoffQuery memory stale commit',
        listings: memoryBatch.listings.length,
        signature: query.signature,
      );
      unawaited(
        _commitInstall(
          memoryBatch.listings,
          query: query,
          generation: generation,
        ),
      );
    }
    return generation;
  }

  /// Handoff + background fetch — overlapping requests are fine; stale gens are dropped.
  void _startQuery(
    MarketBrowseQuery query, {
    required String reason,
    bool revalidate = false,
  }) {
    MarketSearchTrace.event(
      '_startQuery reason=$reason revalidate=$revalidate',
      signature: query.signature,
    );
    final generation = _handoffQuery(
      query,
      reason: reason,
      revalidate: revalidate,
    );
    if (generation == null) return;
    unawaited(
      _fetchFirstPage(
        query: query,
        generation: generation,
        revalidate: revalidate,
      ),
    );
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
    final generation = _handoffQuery(
      query,
      reason: 'refresh',
      revalidate: true,
    );
    if (generation == null) return;
    await _fetchFirstPage(
      query: query,
      generation: generation,
      revalidate: true,
    );
  }

  Future<void> loadMore() async {
    if (!MarketGatewayConfig.isActive || _session.state.isLoadingMore) return;
    if (!_session.state.hasMore) return;

    final generation = _session.state.generation;
    final baseQuery = _session.state.query;
    _session.markLoadingMore(generation: generation);
    _publishState();

    final page = await _ebay.fetchNextPage(baseQuery);
    if (!_ownsGeneration(generation, baseQuery)) return;

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
      query: baseQuery,
      generation: generation,
    );
  }

  Future<void> _fetchFirstPage({
    required MarketBrowseQuery query,
    required int generation,
    required bool revalidate,
  }) async {
    MarketSearchTrace.event(
      '_fetchFirstPage start gen=$generation',
      signature: query.signature,
    );
    final diskBatch = await MarketSearchTrace.asyncSection(
      'resolveCachedBatchFor',
      () => _ebay.resolveCachedBatchFor(query),
    );
    if (!_ownsGeneration(generation, query)) return;

    if (diskBatch != null && diskBatch.listings.isNotEmpty) {
      MarketSearchTrace.event(
        'disk hydrate before network',
        listings: diskBatch.listings.length,
        signature: query.signature,
      );
      final currentCount = _session.state.listings.length;
      if (currentCount == 0 || diskBatch.listings.length > currentCount) {
        _session.hydrateStaleListings(
          generation: generation,
          listings: diskBatch.listings,
          staleCursor: diskBatch.nextCursor,
          staleHasMore: diskBatch.hasMore,
        );
        _publishState();
        unawaited(
          _commitInstall(
            diskBatch.listings,
            query: query,
            generation: generation,
          ),
        );
      }
    }

    final page = await MarketSearchTrace.asyncSection(
      'gateway.fetchFirstPage',
      () => _ebay.fetchFirstPage(query),
      gapWarnMs: 500,
    );
    if (!_ownsGeneration(generation, query)) return;

    MarketSearchTrace.event(
      'network response received',
      listings: page.listings.length,
      signature: query.signature,
    );

    if (page.listings.isEmpty && !page.fromCache) {
      final err = EbayGatewayMarketSource.lastFetchError;
      if (err != null) {
        _session.applyError(
          generation: generation,
          message: err,
        );
        _publishState();
        MarketSearchTrace.event(
          '_fetchFirstPage END applyError (skipped _commitInstall)',
          signature: query.signature,
          gapWarnMs: 1000,
        );
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
    MarketSearchTrace.event(
      '_fetchFirstPage END gen=$generation',
      listings: page.listings.length,
      signature: query.signature,
    );
  }

  /// Identity enrich + aggregation — yield a frame before heavy sync work.
  Future<void> _commitInstall(
    List<MarketListing> listings, {
    required MarketBrowseQuery query,
    required int generation,
  }) async {
    if (!_ownsGeneration(generation, query)) return;
    MarketSearchTrace.event(
      '_commitInstall START gen=$generation',
      listings: listings.length,
      signature: query.signature,
    );
    await Future<void>.delayed(Duration.zero);
    if (!_ownsGeneration(generation, query)) return;
    MarketSearchTrace.sync(
      '_commitInstall.installLiveBrowseListings',
      () => installLiveBrowseListings(listings, query: query),
      warnMs: 12,
    );
    _scheduleBrowseProviderRefresh(generation: generation);
    MarketSearchTrace.event(
      '_commitInstall END gen=$generation',
      listings: listings.length,
      gapWarnMs: 1000,
    );
  }

  /// Refresh browse-derived providers after session singletons update.
  ///
  /// Deferred to the next frame so async gateway work cannot invalidate during
  /// an in-flight provider build (avoids Riverpod re-entrancy exceptions).
  void _scheduleBrowseProviderRefresh({required int generation}) {
    if (!_isActive) return;
    SchedulerBinding.instance.scheduleFrameCallback((_) {
      if (!_isActive) return;
      if (generation != _session.state.generation) return;
      MarketSearchTrace.event(
        'provider invalidation gen=$generation',
        signature: _session.state.querySignature,
      );
      ref.invalidate(marketBrowseListingsProvider);
      ref.invalidate(collectibleMarketSnapshotsProvider);
    });
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
