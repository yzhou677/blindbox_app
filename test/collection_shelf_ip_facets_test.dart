import 'package:blindbox_app/features/collection/presentation/collection_shelf_brand_facets.dart';
import 'package:blindbox_app/features/collection/presentation/collection_shelf_ip_facets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/collection_fixtures.dart';

void main() {
  test('dynamic IP chips from brand-filtered shelf subset', () {
    final popMonsters = testShelfSeries(
      id: 'm1',
      brand: 'POP MART',
      ipName: 'THE MONSTERS',
      taxonomyIpId: 'the_monsters',
    );
    final popHirono = testShelfSeries(
      id: 'h1',
      brand: 'POP MART',
      ipName: 'Hirono',
      taxonomyIpId: 'hirono',
    );
    final top = testShelfSeries(
      id: 't1',
      brand: 'TOP TOY',
      ipName: 'TNT SPACE',
      taxonomyBrandId: 'tntspace',
      taxonomyIpId: 'tnt_space',
    );

    final brandFiltered = shelfSeriesVisibleForBrandFilter(
      [popMonsters, popHirono, top],
      'popmart',
    );
    final options = buildCollectionShelfIpFilterOptions(brandFiltered);

    expect(options.map((o) => o.id).toList(), [
      collectionAnyIpFilterId,
      'themonsters',
      'hirono',
    ]);
    expect(options.firstWhere((o) => o.id == 'themonsters').label, 'THE MONSTERS');
    expect(options.firstWhere((o) => o.id == 'hirono').label, 'Hirono');
  });

  test('THE MONSTERS aliases collapse to one IP chip', () {
    final series = [
      testShelfSeries(
        id: 'a',
        ipName: 'THE MONSTERS',
        taxonomyIpId: 'the_monsters',
      ),
      testShelfSeries(
        id: 'b',
        ipName: 'The Monsters',
        taxonomyIpId: 'the_monsters',
      ),
      testShelfSeries(
        id: 'c',
        ipName: 'the-monsters',
        taxonomyBrandId: 'pop_mart',
        taxonomyIpId: 'the_monsters',
      ),
    ];

    final options = buildCollectionShelfIpFilterOptions(series);

    expect(options.where((o) => o.id == 'themonsters').length, 1);
    expect(options.where((o) => o.label == 'THE MONSTERS').length, 1);
  });

  test('catalog THE MONSTERS and custom The Monsters merge to one chip', () {
    final catalog = testShelfSeries(
      id: 'cat',
      ipName: 'THE MONSTERS',
      taxonomyIpId: 'the_monsters',
      catalogTemplateId: 'catalog_monsters',
    );
    final custom = testShelfSeries(
      id: 'custom-1',
      ipName: 'The Monsters',
      taxonomyIpId: 'the_monsters',
      catalogTemplateId: null,
    );

    final options = buildCollectionShelfIpFilterOptions([catalog, custom]);

    expect(options.where((o) => o.id == 'themonsters').length, 1);
  });

  test('custom Independent and Moon Bears IP chip', () {
    final series = testShelfSeries(
      id: 'custom',
      brand: 'Independent',
      ipName: 'Moon Bears',
      taxonomyBrandId: 'independent',
      taxonomyIpId: 'moon_bears',
      catalogTemplateId: null,
    );

    final options = buildCollectionShelfIpFilterOptions([series]);

    expect(
      options,
      [
        (id: collectionAnyIpFilterId, label: 'All IPs'),
        (id: 'moonbears', label: 'Moon Bears'),
      ],
    );
  });

  test('canonical custom IP uses registry display label with stable filter id', () {
    final series = testShelfSeries(
      id: 'custom_baby_three',
      brand: 'DPL',
      ipName: 'Baby Three',
      taxonomyBrandId: 'dpl',
      taxonomyIpId: 'baby_three',
      catalogTemplateId: null,
    );

    final options = buildCollectionShelfIpFilterOptions([series]);

    expect(options, [
      (id: collectionAnyIpFilterId, label: 'All IPs'),
      (id: 'babythree', label: 'Baby Three'),
    ]);
    expect(
      shelfSeriesVisibleForIpFilter([series], 'babythree'),
      [series],
    );
  });

  test('custom POP MART fan-art IP uses shelf label when registry misses', () {
    final series = testShelfSeries(
      id: 'fan',
      brand: 'POP MART',
      ipName: 'Custom Labubu Fan Art',
      taxonomyBrandId: 'pop_mart',
      taxonomyIpId: 'custom_labubu_fan_art',
      catalogTemplateId: null,
    );

    final options = buildCollectionShelfIpFilterOptions([series]);

    expect(options.last.id, 'customlabubufanart');
    expect(options.last.label, 'Custom Labubu Fan Art');
  });

  test('null taxonomyIpId falls back to ipName label', () {
    final series = testShelfSeries(
      id: 'dimoo',
      ipName: 'Dimoo',
      taxonomyIpId: null,
    );

    final options = buildCollectionShelfIpFilterOptions([series]);

    expect(options.last.id, 'dimoo');
    expect(options.last.label, 'Dimoo');
  });

  test('removing last series for selected IP forces All on resolve', () {
    final hirono = testShelfSeries(
      id: 'h1',
      ipName: 'Hirono',
      taxonomyIpId: 'hirono',
    );
    final withHirono = buildCollectionShelfIpFilterOptions([hirono]);
    expect(
      resolveCollectionIpFilterSelection(
        selectedIpFilterId: 'hirono',
        options: withHirono,
      ),
      'hirono',
    );

    final withoutHirono = buildCollectionShelfIpFilterOptions([]);
    expect(
      resolveCollectionIpFilterSelection(
        selectedIpFilterId: 'hirono',
        options: withoutHirono,
      ),
      collectionAnyIpFilterId,
    );
  });

  test('stale IP selection resets to All', () {
    final options = [
      (id: collectionAnyIpFilterId, label: 'All IPs'),
      (id: 'hirono', label: 'Hirono'),
    ];

    expect(
      resolveCollectionIpFilterSelection(
        selectedIpFilterId: 'skullpanda',
        options: options,
      ),
      collectionAnyIpFilterId,
    );
  });

  test('brand change drops IP chip not present in scoped subset', () {
    final popHirono = testShelfSeries(
      id: 'h1',
      brand: 'POP MART',
      ipName: 'Hirono',
      taxonomyIpId: 'hirono',
    );
    final top = testShelfSeries(
      id: 't1',
      brand: 'TOP TOY',
      ipName: 'TNT SPACE',
      taxonomyBrandId: 'tntspace',
      taxonomyIpId: 'tnt_space',
    );

    final allIps = buildCollectionShelfIpFilterOptions([popHirono, top]);
    expect(
      resolveCollectionIpFilterSelection(
        selectedIpFilterId: 'hirono',
        options: allIps,
      ),
      'hirono',
    );

    final topOnly = shelfSeriesVisibleForBrandFilter([popHirono, top], 'toptoy');
    final topIpOptions = buildCollectionShelfIpFilterOptions(topOnly);
    expect(
      resolveCollectionIpFilterSelection(
        selectedIpFilterId: 'hirono',
        options: topIpOptions,
      ),
      collectionAnyIpFilterId,
    );
  });

  test('IP filter preserves shelf order', () {
    final a = testShelfSeries(id: 'a', ipName: 'Hirono', taxonomyIpId: 'hirono');
    final b = testShelfSeries(id: 'b', ipName: 'Hirono', taxonomyIpId: 'hirono');
    final c = testShelfSeries(
      id: 'c',
      ipName: 'Skullpanda',
      taxonomyIpId: 'skullpanda',
    );

    final filtered = shelfSeriesVisibleForIpFilter([a, b, c], 'hirono');

    expect(filtered.map((s) => s.id).toList(), ['a', 'b']);
  });

  test('large shelf with many distinct IPs builds options without error', () {
    final series = [
      for (var i = 0; i < 50; i++)
        testShelfSeries(
          id: 's$i',
          ipName: 'Unique IP $i',
          taxonomyIpId: 'unique_ip_$i',
        ),
    ];

    final options = buildCollectionShelfIpFilterOptions(series);

    expect(options.length, 51);
    expect(options.first.id, collectionAnyIpFilterId);
  });

  test('shared facet normalization collapses brand and IP the same way', () {
    expect(normalizeCollectionFacetFilterKey('POP MART'), 'popmart');
    expect(normalizeCollectionFacetFilterKey('THE MONSTERS'), 'themonsters');
    expect(normalizeCollectionFacetFilterKey('pino jelly'), 'pinojelly');
    expect(normalizeCollectionFacetFilterKey('pino_jelly'), 'pinojelly');
  });

  test('legacy brand dot ip line uses IP portion only', () {
    final series = testShelfSeries(
      id: 'legacy',
      brand: 'POP MART',
      ipName: 'POP MART · THE MONSTERS',
      taxonomyIpId: 'the_monsters',
    );

    expect(collectionIpFilterKeyForSeries(series), 'themonsters');
  });
}
