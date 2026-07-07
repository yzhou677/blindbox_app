import 'package:blindbox_app/features/catalog/application/catalog_bundle_provider.dart';
import 'package:blindbox_app/features/catalog/catalog_latest_series.dart';
import 'package:blindbox_app/features/collection/application/collection_notifier.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Latest Add Series recommendation rows — synchronous projection of catalog +
/// shelf. Rebuilds when either changes without async loading flashes.
final addSeriesCatalogRecommendationsProvider =
    Provider<List<CatalogSeries>>((ref) {
  ref.watch(catalogBundleRevisionProvider);
  final bundle = resolveCatalogBundleForSearch(
    providerBundle: ref.watch(catalogBundleProvider).valueOrNull,
  );
  if (bundle == null) return const [];

  final snap = ref.watch(collectionNotifierProvider);
  final lookup = ref.watch(catalogBundleLookupProvider);
  if (lookup == null) return const [];

  final picks = pickLatestSeriesRecommendations(bundle, snap);
  return [
    for (final seedSeries in picks)
      if (lookup.seriesTemplate(seedSeries.id) case final template?) template,
  ];
});
