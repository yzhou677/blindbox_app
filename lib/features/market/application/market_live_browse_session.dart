import 'package:blindbox_app/features/market/domain/market_browse_query.dart';
import 'package:blindbox_app/models/market_listing.dart';
import 'package:flutter/foundation.dart';

/// Live browse session state — query signature, pagination, and in-flight guards.
@immutable
class MarketLiveBrowseState {
  const MarketLiveBrowseState({
    this.query = const MarketBrowseQuery(),
    this.listings = const [],
    this.nextCursor,
    this.hasMore = false,
    this.isLoadingInitial = false,
    this.isLoadingMore = false,
    this.isRefreshing = false,
    this.fromStaleCache = false,
    this.errorMessage,
    this.generation = 0,
  });

  final MarketBrowseQuery query;
  final List<MarketListing> listings;
  final String? nextCursor;
  final bool hasMore;
  final bool isLoadingInitial;
  final bool isLoadingMore;
  final bool isRefreshing;
  final bool fromStaleCache;
  final String? errorMessage;
  final int generation;

  String get querySignature => query.signature;

  bool get hasListings => listings.isNotEmpty;

  bool get isBusy => isLoadingInitial || isLoadingMore || isRefreshing;

  MarketLiveBrowseState copyWith({
    MarketBrowseQuery? query,
    List<MarketListing>? listings,
    String? nextCursor,
    bool? hasMore,
    bool? isLoadingInitial,
    bool? isLoadingMore,
    bool? isRefreshing,
    bool? fromStaleCache,
    String? errorMessage,
    bool clearError = false,
    int? generation,
  }) {
    return MarketLiveBrowseState(
      query: query ?? this.query,
      listings: listings ?? this.listings,
      nextCursor: nextCursor ?? this.nextCursor,
      hasMore: hasMore ?? this.hasMore,
      isLoadingInitial: isLoadingInitial ?? this.isLoadingInitial,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      fromStaleCache: fromStaleCache ?? this.fromStaleCache,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      generation: generation ?? this.generation,
    );
  }
}

/// Mutable session coordinator — generation guards stale network responses.
final class MarketLiveBrowseSession {
  MarketLiveBrowseState _state = const MarketLiveBrowseState();

  MarketLiveBrowseState get state => _state;

  int bumpGeneration() {
    final next = _state.generation + 1;
    _state = _state.copyWith(generation: next);
    return next;
  }

  /// Reset for a new query signature — optionally hydrate from stale cache first.
  void resetForQuery(
    MarketBrowseQuery query, {
    List<MarketListing>? staleListings,
    String? staleCursor,
    bool staleHasMore = false,
  }) {
    final generation = bumpGeneration();
    _state = MarketLiveBrowseState(
      query: query.copyWith(clearCursor: true),
      listings: staleListings ?? const [],
      nextCursor: staleCursor,
      hasMore: staleHasMore,
      fromStaleCache: staleListings != null && staleListings.isNotEmpty,
      generation: generation,
    );
  }

  void markLoadingInitial({required int generation}) {
    if (generation != _state.generation) return;
    _state = _state.copyWith(
      isLoadingInitial: true,
      isRefreshing: false,
      clearError: true,
    );
  }

  void markRefreshing({required int generation}) {
    if (generation != _state.generation) return;
    _state = _state.copyWith(
      isRefreshing: true,
      clearError: true,
    );
  }

  void markLoadingMore({required int generation}) {
    if (generation != _state.generation) return;
    _state = _state.copyWith(isLoadingMore: true, clearError: true);
  }

  void applyFirstPage({
    required int generation,
    required List<MarketListing> listings,
    String? nextCursor,
    required bool hasMore,
    MarketBrowseQuery? query,
    bool fromStaleCache = false,
    String? errorMessage,
  }) {
    if (generation != _state.generation) return;
    _state = MarketLiveBrowseState(
      query: (query ?? _state.query).copyWith(clearCursor: true),
      listings: List<MarketListing>.unmodifiable(listings),
      nextCursor: nextCursor,
      hasMore: hasMore,
      fromStaleCache: fromStaleCache,
      errorMessage: errorMessage,
      generation: generation,
    );
  }

  /// Appends the next gateway page — preserves existing rows and clears load-more state.
  void applyNextPage({
    required int generation,
    required List<MarketListing> listings,
    String? nextCursor,
    required bool hasMore,
  }) {
    if (generation != _state.generation) return;
    _state = _state.copyWith(
      listings: List<MarketListing>.unmodifiable(listings),
      nextCursor: nextCursor,
      hasMore: hasMore,
      isLoadingInitial: false,
      isLoadingMore: false,
      isRefreshing: false,
      clearError: true,
    );
  }

  void applyError({required int generation, required String message}) {
    if (generation != _state.generation) return;
    _state = _state.copyWith(
      isLoadingInitial: false,
      isLoadingMore: false,
      isRefreshing: false,
      errorMessage: message,
    );
  }
}
