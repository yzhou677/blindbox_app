import 'package:flutter/foundation.dart';

/// Provider-neutral browse query — maps to upstream keyword search via [MarketBrowseQueryComposer].
@immutable
class MarketBrowseQuery {
  const MarketBrowseQuery({
    this.brandId = anyBrand,
    this.ipId = anyIp,
    this.searchText = '',
    this.sort = MarketBrowseSort.relevance,
    this.cursor,
    this.limit = 12,
  });

  static const String anyBrand = 'any_brand';
  static const String anyIp = 'any_ip';

  final String brandId;
  final String ipId;
  final String searchText;
  final MarketBrowseSort sort;
  final String? cursor;
  final int limit;

  /// Stable key for session reset, cache buckets, and in-flight guards (excludes cursor).
  String get signature =>
      '$brandId|$ipId|${searchText.trim().toLowerCase()}|${sort.wireName}';

  bool get isDefault =>
      brandId == anyBrand &&
      ipId == anyIp &&
      searchText.trim().isEmpty &&
      sort == MarketBrowseSort.relevance;

  MarketBrowseQuery copyWith({
    String? brandId,
    String? ipId,
    String? searchText,
    MarketBrowseSort? sort,
    String? cursor,
    bool clearCursor = false,
    int? limit,
  }) {
    return MarketBrowseQuery(
      brandId: brandId ?? this.brandId,
      ipId: ipId ?? this.ipId,
      searchText: searchText ?? this.searchText,
      sort: sort ?? this.sort,
      cursor: clearCursor ? null : (cursor ?? this.cursor),
      limit: limit ?? this.limit,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MarketBrowseQuery &&
          brandId == other.brandId &&
          ipId == other.ipId &&
          searchText == other.searchText &&
          sort == other.sort &&
          cursor == other.cursor &&
          limit == other.limit;

  @override
  int get hashCode => Object.hash(brandId, ipId, searchText, sort, cursor, limit);
}

enum MarketBrowseSort {
  relevance,
  priceLowToHigh,
  priceHighToLow;

  String get wireName => switch (this) {
        MarketBrowseSort.relevance => 'relevance',
        MarketBrowseSort.priceLowToHigh => 'price_asc',
        MarketBrowseSort.priceHighToLow => 'price_desc',
      };
}
