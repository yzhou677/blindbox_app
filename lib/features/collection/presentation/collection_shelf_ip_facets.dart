import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/collection/presentation/collection_shelf_brand_facets.dart';
import 'package:blindbox_app/features/market/taxonomy/ip_taxonomy_registry.dart';

typedef CollectionIpFilterOption = ({String id, String label});

/// Collection-only sentinel for "show all IPs".
const String collectionAnyIpFilterId = 'any_ip';

String _seriesIpRawKey(ShelfSeries series) {
  final ip = shelfSeriesIpLabel(series).trim();
  if (ip.isNotEmpty) return ip;
  return series.taxonomyIpId?.trim() ?? '';
}

/// Canonical collection IP filter key for a shelf series.
String collectionIpFilterKeyForSeries(ShelfSeries series) {
  return normalizeCollectionFacetFilterKey(_seriesIpRawKey(series));
}

String? _taxonomyIpDisplayLabel(String? taxonomyIpId) {
  final id = taxonomyIpId?.trim();
  if (id == null || id.isEmpty) return null;
  for (final ip in IpTaxonomyRegistry.all) {
    if (ip.id == id) return ip.displayName;
  }
  return null;
}

String _ipChipLabelForSeries(ShelfSeries series, String normalizedKey) {
  final fromRegistry = _taxonomyIpDisplayLabel(series.taxonomyIpId);
  if (fromRegistry != null && fromRegistry.isNotEmpty) return fromRegistry;
  final ipLabel = shelfSeriesIpLabel(series).trim();
  if (ipLabel.isNotEmpty) return ipLabel;
  final taxFallback = series.taxonomyIpId?.trim() ?? '';
  if (taxFallback.isNotEmpty) return taxFallback;
  return normalizedKey;
}

/// Returns shelf series visible under [ipFilterId] (input should already be brand-filtered).
List<ShelfSeries> shelfSeriesVisibleForIpFilter(
  List<ShelfSeries> shelfSeries,
  String ipFilterId,
) {
  if (ipFilterId == collectionAnyIpFilterId) return shelfSeries;
  return shelfSeries
      .where((series) => collectionIpFilterKeyForSeries(series) == ipFilterId)
      .toList(growable: false);
}

/// Build IP chip options from [shelfSeries] (typically brand-filtered subset).
///
/// Preserves first-seen shelf order for stable UX.
List<CollectionIpFilterOption> buildCollectionShelfIpFilterOptions(
  List<ShelfSeries> shelfSeries,
) {
  final options = <CollectionIpFilterOption>[
    (id: collectionAnyIpFilterId, label: 'All IPs'),
  ];
  final seen = <String>{collectionAnyIpFilterId};

  for (final series in shelfSeries) {
    final key = collectionIpFilterKeyForSeries(series);
    if (key.isEmpty || seen.contains(key)) continue;
    options.add((id: key, label: _ipChipLabelForSeries(series, key)));
    seen.add(key);
  }

  return options;
}

/// If the selected chip no longer exists in current options, reset to "All".
String resolveCollectionIpFilterSelection({
  required String selectedIpFilterId,
  required List<CollectionIpFilterOption> options,
}) {
  for (final option in options) {
    if (option.id == selectedIpFilterId) return selectedIpFilterId;
  }
  return collectionAnyIpFilterId;
}
