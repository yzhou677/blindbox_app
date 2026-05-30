import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/collection/presentation/collection_shelf_brand_facets.dart'
    as facets;

/// Backward-compatible shim for Collection shelf filter imports.
List<ShelfSeries> shelfSeriesVisibleForBrandFilter(
  List<ShelfSeries> shelfSeries,
  String brandFilterId,
) => facets.shelfSeriesVisibleForBrandFilter(shelfSeries, brandFilterId);
