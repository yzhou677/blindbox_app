import 'package:blindbox_app/features/catalog/catalog_bundle.dart';
import 'package:blindbox_app/features/catalog/presentation/catalog_series_search_rows.dart';
import 'package:blindbox_app/features/catalog/search/catalog_search_service.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/collection/presentation/collection_shelf_browse.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/collection_fixtures.dart';

/// Catalog fixture with figures, aliases, and multiple IPs — enough surface for
/// cross-field queries (figure, series, IP, brand, alias).
CatalogSeedBundle _parityCatalogBundle() {
  return CatalogSeedBundle(
    brands: parseCatalogBrandsJson(r'''[
      {"id": "pop_mart", "displayName": "POP MART", "aliases": ["POPMART"]}
    ]'''),
    ips: parseCatalogIpsJson(r'''[
      {"id": "the_monsters", "brandId": "pop_mart", "displayName": "THE MONSTERS",
       "aliases": ["Labubu"]},
      {"id": "hirono", "brandId": "pop_mart", "displayName": "Hirono", "aliases": []}
    ]'''),
    series: parseCatalogSeriesJson(r'''[
      {"id": "macaron", "brandId": "pop_mart", "ipId": "the_monsters",
       "displayName": "THE MONSTERS - Exciting Macaron Vinyl Face Blind Box",
       "releaseDate": "2023-10-27", "isBlindBox": true,
       "thumbnailAsset": "assets/catalog/series/macaron.png"},
      {"id": "wild", "brandId": "pop_mart", "ipId": "hirono",
       "displayName": "Hirono Boundary — Test Series", "releaseDate": "2026-04-02",
       "isBlindBox": true, "imageKey": "wild",
       "aliases": ["Quiet Garden"]},
      {"id": "alias_only", "brandId": "pop_mart", "ipId": "hirono",
       "displayName": "Obscure Official Title", "releaseDate": "2026-03-01",
       "isBlindBox": true, "imageKey": "alias_only", "aliases": ["Moonlight"]}
    ]'''),
    figures: parseCatalogFiguresJson(r'''[
      {"id": "fig_soy", "seriesId": "macaron", "brandId": "pop_mart",
       "ipId": "the_monsters", "displayName": "Soymilk", "isSecret": false,
       "sortOrder": 1, "thumbnailAsset": "assets/f/soy.png"},
      {"id": "fig_lumi", "seriesId": "macaron", "brandId": "pop_mart",
       "ipId": "the_monsters", "displayName": "Hi Lumi", "isSecret": false,
       "sortOrder": 2, "thumbnailAsset": "assets/f/lumi.png"},
      {"id": "fig_chase", "seriesId": "macaron", "brandId": "pop_mart",
       "ipId": "the_monsters", "displayName": "Chestnut Cocoa", "isSecret": true,
       "rarityLabel": "1/72", "sortOrder": 999, "thumbnailAsset": "assets/f/chase.png"},
      {"id": "fig_hirono", "seriesId": "wild", "brandId": "pop_mart", "ipId": "hirono",
       "displayName": "Quiet Rain", "isSecret": false, "sortOrder": 1,
       "imageKey": "fig_hirono"},
      {"id": "fig_moon", "seriesId": "alias_only", "brandId": "pop_mart", "ipId": "hirono",
       "displayName": "Lunar", "isSecret": false, "sortOrder": 1, "imageKey": "fig_moon"}
    ]'''),
  );
}

List<ShelfSeries> _ownedCatalogShelf(CatalogSeedBundle catalog) {
  ShelfSeries catalogRow(String catalogSeriesId, {String? shelfId}) {
    final series = catalog.series.firstWhere((s) => s.id == catalogSeriesId);
    final figures = catalog.figures.where((f) => f.seriesId == catalogSeriesId);
    return testShelfSeries(
      id: shelfId ?? 'shelf_$catalogSeriesId',
      name: series.displayName,
      catalogTemplateId: catalogSeriesId,
      taxonomyBrandId: series.brandId,
      taxonomyIpId: series.ipId,
      figures: [
        for (final f in figures)
          ShelfFigure(
            id: 'shelf_${catalogSeriesId}_${f.id}',
            seriesId: shelfId ?? 'shelf_$catalogSeriesId',
            name: f.displayName,
            rarity: f.isSecret ? 'Secret' : 'Regular',
            isSecret: f.isSecret,
            catalogFigureTemplateId: f.id,
          ),
      ],
    );
  }

  return [
    catalogRow('macaron'),
    catalogRow('wild'),
    // Drop-import style key — common on Home release saves.
    testShelfSeries(
      id: 'shelf_drop_alias',
      name: 'Obscure Official Title',
      catalogTemplateId: 'drop-alias_only',
      taxonomyBrandId: 'pop_mart',
      taxonomyIpId: 'hirono',
      figures: [
        const ShelfFigure(
          id: 'shelf_drop_alias_fig',
          seriesId: 'shelf_drop_alias',
          name: 'Lunar',
          rarity: 'Regular',
          isSecret: false,
          catalogFigureTemplateId: 'fig_moon',
        ),
      ],
    ),
  ];
}

/// Discover browse rows — same series-id set as [CatalogSearchService.search].
Set<String> _discoverSeriesIds(CatalogSeedBundle catalog, String query) {
  return buildCatalogSeriesSearchRows(bundle: catalog, query: query)
      .map((row) => row.seriesId)
      .toSet();
}

/// Catalog series ids represented by Collection rows after search filtering.
Set<String> _collectionCatalogSeriesIds(
  CatalogSeedBundle catalog,
  Iterable<ShelfSeries> filtered,
) {
  final knownSeriesIds = {for (final s in catalog.series) s.id};
  final figureSeriesLookup = {
    for (final f in catalog.figures) f.id: f.seriesId,
  };
  final out = <String>{};

  for (final row in filtered) {
    for (final candidate in shelfCatalogSeriesIdCandidates(row)) {
      if (knownSeriesIds.contains(candidate)) out.add(candidate);
    }
    for (final fig in row.figures) {
      final templateId = fig.catalogFigureTemplateId?.trim();
      if (templateId == null || templateId.isEmpty) continue;
      final seriesId = figureSeriesLookup[templateId];
      if (seriesId != null) out.add(seriesId);
    }
  }
  return out;
}

void _expectCollectionSubsetOfDiscover({
  required CatalogSeedBundle catalog,
  required List<ShelfSeries> owned,
  required String query,
}) {
  final discover = _discoverSeriesIds(catalog, query);
  final filtered = filterShelfSeriesBySearch(owned, query, catalog: catalog);
  final collection = _collectionCatalogSeriesIds(catalog, filtered);

  expect(
    collection.difference(discover),
    isEmpty,
    reason:
        'query="$query": collection catalog ids $collection must be subset of '
        'Discover ids $discover',
  );

  // Discover rows API and matchingSeriesIds must stay aligned.
  expect(
    CatalogSearchService(catalog).matchingSeriesIds(query),
    discover,
    reason: 'query="$query": Discover row ids must match matchingSeriesIds',
  );
}

void main() {
  late CatalogSeedBundle catalog;
  late List<ShelfSeries> owned;

  setUp(() {
    catalog = _parityCatalogBundle();
    owned = _ownedCatalogShelf(catalog);
  });

  group('Collection search ⊆ Discover search (catalog series ids)', () {
    const queries = [
      'Hi Lumi',
      'soymilk',
      'chestnut',
      'macaron',
      'exciting macaron',
      'labubu',
      'the monsters',
      'hirono',
      'quiet garden',
      'moonlight',
      'pop mart',
      'popmart',
      'lunar',
      'nomatch-xyz-404',
    ];

    for (final query in queries) {
      test('query "$query"', () {
        _expectCollectionSubsetOfDiscover(
          catalog: catalog,
          owned: owned,
          query: query,
        );
      });
    }

    test('partial ownership still satisfies subset', () {
      final partialOwned = owned.where((s) => s.id != 'shelf_wild').toList();
      for (final query in ['hirono', 'moonlight', 'macaron', 'Hi Lumi']) {
        _expectCollectionSubsetOfDiscover(
          catalog: catalog,
          owned: partialOwned,
          query: query,
        );
      }
    });
  });
}
