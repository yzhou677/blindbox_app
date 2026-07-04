import 'package:blindbox_app/features/catalog/application/catalog_bundle_provider.dart';
import 'package:blindbox_app/features/catalog/catalog_latest_series.dart';
import 'package:blindbox_app/features/collection/application/collection_notifier.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Latest Add Series recommendation rows — rebuilds when catalog or shelf changes.
final addSeriesCatalogRecommendationsProvider =
    FutureProvider<List<CatalogSeries>>((ref) async {
  final bundle = await ref.watch(catalogBundleProvider.future);
  final snap = ref.watch(collectionNotifierProvider);
  final picks = pickLatestSeriesRecommendations(bundle, snap);
  final lookup = ref.watch(catalogBundleLookupProvider);
  if (lookup == null) return const [];
  return [
    for (final seedSeries in picks)
      if (lookup.seriesTemplate(seedSeries.id) case final template?) template,
  ];
});
