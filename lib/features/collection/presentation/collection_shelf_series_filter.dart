import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/market/catalog/market_taxonomy.dart';

/// Local shelf filtering by canonical brand id (aligned with [MarketTaxonomy]).
List<ShelfSeries> shelfSeriesVisibleForBrandFilter(
  List<ShelfSeries> shelfSeries,
  String brandFilterId,
) {
  if (brandFilterId == MarketTaxonomyIds.anyBrand) {
    return shelfSeries;
  }
  return shelfSeries
      .where((s) => s.taxonomyBrandId == brandFilterId)
      .toList(growable: false);
}
