import 'package:blindbox_app/features/catalog/catalog_bundle.dart';
import 'package:blindbox_app/features/catalog/data/catalog_bundle_lookup.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart' as domain;

/// Builds a collection add-sheet / clone template from curated seed JSON.
///
/// Returns null if [seriesId] is unknown or has no figures in the bundle.
///
/// Prefer [CatalogBundleLookup.seriesTemplate] via [catalogSeriesTemplateProvider]
/// on UI hot paths — this helper remains for tests and one-off async call sites.
Future<domain.CatalogSeries?> catalogTemplateFromSeedSeries(
  CatalogSeedBundle bundle,
  String seriesId, {
  /// When false, skips eager URL resolution (deprecated —templates never carry URLs).
  bool resolveFigureImages = true,
  CatalogBundleLookup? lookup,
}) async {
  final resolved = lookup ?? CatalogBundleLookup.fromBundle(bundle);
  return resolved.seriesTemplate(seriesId);
}
