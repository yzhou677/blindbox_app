import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/collection/presentation/collection_shelf_brand_facets.dart'
    as brand;
import 'package:blindbox_app/features/collection/presentation/collection_shelf_ip_facets.dart'
    as ip;

/// Backward-compatible shim for Collection shelf filter imports.
List<ShelfSeries> shelfSeriesVisibleForBrandFilter(
  List<ShelfSeries> shelfSeries,
  String brandFilterId,
) => brand.shelfSeriesVisibleForBrandFilter(shelfSeries, brandFilterId);

List<ShelfSeries> shelfSeriesVisibleForIpFilter(
  List<ShelfSeries> shelfSeries,
  String ipFilterId,
) => ip.shelfSeriesVisibleForIpFilter(shelfSeries, ipFilterId);
