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
}
