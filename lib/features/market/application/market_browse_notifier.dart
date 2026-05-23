import 'package:blindbox_app/features/market/catalog/market_taxonomy.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Market browse + search UI state.
///
/// - [query]: draft text (synced with the search field). Drives listing filter.
/// - [searchResultsActive]: immersive “search results” layout only after
///   [MarketBrowseNotifier.submitSearch]; not tied to field focus.
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

class MarketBrowseNotifier extends Notifier<MarketBrowseState> {
  @override
  MarketBrowseState build() => const MarketBrowseState();

  /// Draft query from the field; clearing text exits [searchResultsActive].
  void setQuery(String value) {
    final empty = value.trim().isEmpty;
    state = state.copyWith(
      query: value,
      searchResultsActive: empty ? false : null,
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

  /// Broadest taxonomy rails — used when live Mercari sandbox refreshes so
  /// provider rows without catalog IP/brand are not filtered out.
  void resetTaxonomyFiltersForSandbox() {
    state = state.copyWith(
      brandId: MarketTaxonomyIds.anyBrand,
      ipId: MarketTaxonomyIds.anyIp,
    );
  }

  /// Enter immersive search after keyboard search / explicit submit.
  void submitSearch() {
    final hasQuery = state.query.trim().isNotEmpty;
    state = state.copyWith(searchResultsActive: hasQuery);
  }

  /// Clear draft query, exit immersive search, keep shelf filters.
  void clearSearchSession() {
    state = state.copyWith(query: '', searchResultsActive: false);
  }
}
