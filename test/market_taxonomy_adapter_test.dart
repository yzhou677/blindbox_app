import 'package:blindbox_app/features/catalog/catalog_seed_loader.dart';
import 'package:blindbox_app/features/catalog/models/catalog_brand.dart';
import 'package:blindbox_app/features/catalog/models/catalog_ip.dart';
import 'package:blindbox_app/features/market/catalog/market_taxonomy.dart';
import 'package:blindbox_app/features/market/taxonomy/brand_taxonomy_registry.dart';
import 'package:blindbox_app/features/market/taxonomy/ip_taxonomy_registry.dart';
import 'package:blindbox_app/features/market/taxonomy/market_filter_visibility.dart';
import 'package:blindbox_app/features/market/taxonomy/market_taxonomy_adapter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('adapter rows mirror registry sizes and ids', () {
    expect(MarketTaxonomyAdapter.buildIpRows().length, IpTaxonomyRegistry.all.length);
    expect(MarketTaxonomyAdapter.buildBrandRows().length, BrandTaxonomyRegistry.all.length);
  });

  test('filter chip brands exclude Finding Unicorn', () {
    expect(
      MarketTaxonomy.brands.map((b) => b.id),
      isNot(contains('finding_unicorn')),
    );
    expect(
      MarketTaxonomy.brandChipOptions().map((o) => o.id),
      isNot(contains('finding_unicorn')),
    );
  });

  test('filter chip POP MART IPs exclude peach riot azura duckoo', () {
    final pop = MarketTaxonomy.brandById('pop_mart');
    expect(pop, isNotNull);
    final filterPop = MarketTaxonomy.brands.firstWhere((b) => b.id == 'pop_mart');
    for (final hidden in ['peach_riot', 'azura', 'duckoo']) {
      expect(filterPop.supportedIpIds, isNot(contains(hidden)));
      expect(MarketFilterVisibility.hiddenIpIds, contains(hidden));
    }
    expect(filterPop.supportedIpIds, contains('the_monsters'));
    final monsters = MarketTaxonomy.allIps.firstWhere((i) => i.id == 'the_monsters');
    expect(monsters.displayLabel, 'THE MONSTERS');
  });

  test('filter chip TNT SPACE IPs exclude anmoo liila', () {
    final tnt = MarketTaxonomy.brands.firstWhere((b) => b.id == 'tntspace');
    expect(tnt.supportedIpIds, isNot(contains('anmoo')));
    expect(tnt.supportedIpIds, isNot(contains('liila')));
  });

  test('brandById still resolves full registry for listings', () {
    final b = MarketTaxonomy.brandById('finding_unicorn');
    expect(b, isNotNull);
    expect(b!.displayLabel, 'Finding Unicorn');
  });

  test('every IP id in filter allIps is unique', () {
    final ids = MarketTaxonomy.allIps.map((e) => e.id).toList();
    expect(ids.toSet().length, ids.length);
  });

  test('applyCatalogBundle uses Firestore brand and ip ids', () {
    final bundle = CatalogSeedBundle(
      brands: const [
        CatalogBrand(id: 'pop_mart', displayName: 'POP MART', aliases: []),
      ],
      ips: const [
        CatalogIp(
          id: 'the_monsters',
          brandId: 'pop_mart',
          displayName: 'THE MONSTERS',
          aliases: ['Labubu'],
        ),
        CatalogIp(
          id: 'peach_riot',
          brandId: 'pop_mart',
          displayName: 'Peach Riot',
          aliases: [],
        ),
      ],
      series: const [],
      figures: const [],
    );
    MarketTaxonomy.applyCatalogBundle(bundle);
    final pop = MarketTaxonomy.brands.firstWhere((b) => b.id == 'pop_mart');
    expect(pop.displayLabel, 'POP MART');
    expect(pop.supportedIpIds, contains('the_monsters'));
    expect(pop.supportedIpIds, isNot(contains('peach_riot')));
    expect(MarketTaxonomy.allIps.map((i) => i.id), contains('the_monsters'));
  });

  test('filter chips hide generic molly when baby_molly or space_molly present', () {
    final bundle = CatalogSeedBundle(
      brands: const [
        CatalogBrand(id: 'pop_mart', displayName: 'POP MART', aliases: []),
      ],
      ips: const [
        CatalogIp(id: 'molly', brandId: 'pop_mart', displayName: 'Molly', aliases: []),
        CatalogIp(id: 'baby_molly', brandId: 'pop_mart', displayName: 'Baby Molly', aliases: []),
        CatalogIp(id: 'space_molly', brandId: 'pop_mart', displayName: 'Space Molly', aliases: []),
      ],
      series: const [],
      figures: const [],
    );
    MarketTaxonomy.applyCatalogBundle(bundle);
    final ipIds = MarketTaxonomy.allIps.map((i) => i.id).toSet();
    expect(ipIds, containsAll(['baby_molly', 'space_molly']));
    expect(ipIds, isNot(contains('molly')));
    final popIpIds = MarketTaxonomy.ipChipOptionsForBrand('pop_mart').map((o) => o.id);
    expect(popIpIds, containsAll(['baby_molly', 'space_molly']));
    expect(popIpIds, isNot(contains('molly')));
  });

  test('ipChipOptionsForBrand uses Firestore-backed filter rows not adapter registry', () {
    final bundle = CatalogSeedBundle(
      brands: const [
        CatalogBrand(id: 'pop_mart', displayName: 'POP MART', aliases: []),
      ],
      ips: const [
        CatalogIp(
          id: 'the_monsters',
          brandId: 'pop_mart',
          displayName: 'THE MONSTERS',
          aliases: ['Labubu'],
        ),
        CatalogIp(
          id: 'peach_riot',
          brandId: 'pop_mart',
          displayName: 'Peach Riot',
          aliases: [],
        ),
      ],
      series: const [],
      figures: const [],
    );
    MarketTaxonomy.applyCatalogBundle(bundle);
    final ipIds = MarketTaxonomy.ipChipOptionsForBrand('pop_mart').map((o) => o.id);
    expect(ipIds, contains('the_monsters'));
    expect(ipIds, isNot(contains('peach_riot')));
    expect(
      MarketTaxonomy.ipChipOptionsForBrand('pop_mart').firstWhere((o) => o.id == 'the_monsters').label,
      'THE MONSTERS',
    );
  });
}
