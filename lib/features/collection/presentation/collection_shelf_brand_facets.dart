import 'package:blindbox_app/features/collection/domain/collection_domain.dart';

typedef CollectionBrandFilterOption = ({String id, String label});

/// Collection-only sentinel for "show all brands".
const String collectionAnyBrandFilterId = 'any_brand';

const Map<String, String> _collectionBrandAliasDisplayByKey = {
  'popmart': 'POP MART',
  'toptoy': 'TOP TOY',
  'rolife': 'ROLIFE',
};

/// Collection filter canonicalization only (presentation-layer grouping).
///
/// Rules:
/// - lowercase
/// - remove spaces / underscores
/// - remove punctuation and other non [a-z0-9]
String normalizeCollectionFacetFilterKey(String input) {
  final lower = input.trim().toLowerCase();
  if (lower.isEmpty) return '';
  final compact = lower.replaceAll(RegExp(r'[\s_]'), '');
  return compact.replaceAll(RegExp(r'[^a-z0-9]'), '');
}

String _seriesBrandRawKey(ShelfSeries series) {
  final brand = series.brand.trim();
  if (brand.isNotEmpty) return brand;
  return series.taxonomyBrandId?.trim() ?? '';
}

/// Canonical collection filter key for a shelf series.
String collectionBrandFilterKeyForSeries(ShelfSeries series) {
  return normalizeCollectionFacetFilterKey(_seriesBrandRawKey(series));
}

/// Returns shelf series visible under [brandFilterId].
List<ShelfSeries> shelfSeriesVisibleForBrandFilter(
  List<ShelfSeries> shelfSeries,
  String brandFilterId,
) {
  if (brandFilterId == collectionAnyBrandFilterId) return shelfSeries;
  return shelfSeries
      .where((series) => collectionBrandFilterKeyForSeries(series) == brandFilterId)
      .toList(growable: false);
}

/// Build Collection chip options from brands currently present on shelf.
///
/// Preserves first-seen order of shelf brands for stable UX.
List<CollectionBrandFilterOption> buildCollectionShelfBrandFilterOptions(
  List<ShelfSeries> shelfSeries,
) {
  final options = <CollectionBrandFilterOption>[
    (id: collectionAnyBrandFilterId, label: 'All Brands'),
  ];
  final seen = <String>{collectionAnyBrandFilterId};

  for (final series in shelfSeries) {
    final key = collectionBrandFilterKeyForSeries(series);
    if (key.isEmpty || seen.contains(key)) continue;
    final aliasLabel = _collectionBrandAliasDisplayByKey[key];
    final brandLabel = series.brand.trim();
    final fallback = series.taxonomyBrandId?.trim() ?? '';
    final label = aliasLabel ??
        (brandLabel.isNotEmpty ? brandLabel : (fallback.isNotEmpty ? fallback : key));
    options.add((id: key, label: label));
    seen.add(key);
  }

  return options;
}

/// If the selected chip no longer exists in current options, reset to "All".
String resolveCollectionBrandFilterSelection({
  required String selectedBrandFilterId,
  required List<CollectionBrandFilterOption> options,
}) {
  for (final option in options) {
    if (option.id == selectedBrandFilterId) return selectedBrandFilterId;
  }
  return collectionAnyBrandFilterId;
}
