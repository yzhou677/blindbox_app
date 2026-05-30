import 'package:blindbox_app/features/market/catalog/market_taxonomy.dart';
import 'package:blindbox_app/features/market/presentation/market_price_sort.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

export 'market_browse_root_navigation.dart' show isMarketBrowseRootPath, kMarketBrowseRootPath;

/// Market tab browse filters — independent from Search Market overlay state.
@immutable
class MarketFeedBrowseState {
  const MarketFeedBrowseState({
    this.brandId = MarketTaxonomyIds.anyBrand,
    this.ipId = MarketTaxonomyIds.anyIp,
    this.priceSort = MarketPriceSort.lowToHigh,
  });

  final String brandId;
  final String ipId;
  final MarketPriceSort priceSort;

  bool get filtersActive =>
      brandId != MarketTaxonomyIds.anyBrand || ipId != MarketTaxonomyIds.anyIp;

  MarketFeedBrowseState copyWith({
    String? brandId,
    String? ipId,
    MarketPriceSort? priceSort,
  }) {
    return MarketFeedBrowseState(
      brandId: brandId ?? this.brandId,
      ipId: ipId ?? this.ipId,
      priceSort: priceSort ?? this.priceSort,
    );
  }
}

final marketFeedBrowseNotifierProvider =
    NotifierProvider<MarketFeedBrowseNotifier, MarketFeedBrowseState>(
  MarketFeedBrowseNotifier.new,
);

class MarketFeedBrowseNotifier extends Notifier<MarketFeedBrowseState> {
  @override
  MarketFeedBrowseState build() => const MarketFeedBrowseState();

  void setBrand(String id) {
    final ipId = id == MarketTaxonomyIds.anyBrand
        ? MarketTaxonomyIds.anyIp
        : MarketTaxonomy.clampIpToBrand(id, state.ipId);
    state = state.copyWith(
      brandId: id,
      ipId: ipId,
    );
  }

  void setIp(String id) {
    state = state.copyWith(ipId: id);
  }

  void setPriceSort(MarketPriceSort sort) {
    state = state.copyWith(priceSort: sort);
  }

  void togglePriceSort() {
    state = state.copyWith(
      priceSort: state.priceSort == MarketPriceSort.lowToHigh
          ? MarketPriceSort.highToLow
          : MarketPriceSort.lowToHigh,
    );
  }

  /// Broadest taxonomy rails — Mercari sandbox refresh only.
  void resetTaxonomyFiltersForSandbox() {
    state = state.copyWith(
      brandId: MarketTaxonomyIds.anyBrand,
      ipId: MarketTaxonomyIds.anyIp,
    );
  }
}
