import 'package:blindbox_app/features/market/catalog/market_taxonomy.dart';
import 'package:blindbox_app/features/market/debug/market_search_trace.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Market browse + search UI state.
///
/// - [query]: draft text synced with the search field.
/// - [searchResultsActive]: true when the user has a non-empty search query
///   (live gateway search via [MarketLiveBrowseController]).
@immutable
class MarketBrowseState {
  const MarketBrowseState({
    this.query = '',
    this.brandId = MarketTaxonomyIds.anyBrand,
    this.ipId = MarketTaxonomyIds.anyIp,
    this.searchResultsActive = false,
  });

  final String query;
  final String brandId;
  final String ipId;
  final bool searchResultsActive;

  bool get filtersActive =>
      brandId != MarketTaxonomyIds.anyBrand || ipId != MarketTaxonomyIds.anyIp;

  MarketBrowseState copyWith({
    String? query,
    String? brandId,
    String? ipId,
    bool? searchResultsActive,
  }) {
    return MarketBrowseState(
      query: query ?? this.query,
      brandId: brandId ?? this.brandId,
      ipId: ipId ?? this.ipId,
      searchResultsActive: searchResultsActive ?? this.searchResultsActive,
    );
  }
}

final marketBrowseNotifierProvider =
    NotifierProvider<MarketBrowseNotifier, MarketBrowseState>(MarketBrowseNotifier.new);

/// True when the Market tab shows its root feed (not `/market/search` or a child).
bool isMarketBrowseRootPath(String path) => path == '/market';

class MarketBrowseNotifier extends Notifier<MarketBrowseState> {
  @override
  MarketBrowseState build() => const MarketBrowseState();

  /// Draft query from the field; activates live search when non-empty.
  void setQuery(String value) {
    final empty = value.trim().isEmpty;
    MarketSearchTrace.event(
      'marketBrowseNotifier.setQuery active=${!empty}',
      signature: value.trim().toLowerCase(),
    );
    state = state.copyWith(
      query: value,
      searchResultsActive: !empty,
    );
  }

  void setBrand(String id) {
    state = state.copyWith(
      brandId: id,
      ipId: MarketTaxonomy.clampIpToBrand(id, state.ipId),
    );
  }

  void setIp(String id) {
    state = state.copyWith(ipId: id);
  }

  /// Broadest taxonomy rails — Mercari sandbox refresh only.
  void resetTaxonomyFiltersForSandbox() {
    state = state.copyWith(
      brandId: MarketTaxonomyIds.anyBrand,
      ipId: MarketTaxonomyIds.anyIp,
    );
  }

  /// Clear draft query, exit search mode, keep brand/IP filters.
  void clearSearchSession() {
    state = state.copyWith(query: '', searchResultsActive: false);
  }
}
