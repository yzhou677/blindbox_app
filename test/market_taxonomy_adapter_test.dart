import 'package:blindbox_app/features/market/catalog/market_taxonomy.dart';
import 'package:blindbox_app/features/market/taxonomy/brand_taxonomy_registry.dart';
import 'package:blindbox_app/features/market/taxonomy/ip_taxonomy_registry.dart';
import 'package:blindbox_app/features/market/taxonomy/market_taxonomy_adapter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('adapter rows mirror registry sizes and ids', () {
    expect(MarketTaxonomyAdapter.buildIpRows().length, IpTaxonomyRegistry.all.length);
    expect(MarketTaxonomyAdapter.buildBrandRows().length, BrandTaxonomyRegistry.all.length);
  });

  test('MarketTaxonomy brands include all IPs for pop_mart from registry', () {
    final b = MarketTaxonomy.brandById('pop_mart');
    expect(b, isNotNull);
    final expected = [
      for (final ip in IpTaxonomyRegistry.all)
        if (ip.brandId == 'pop_mart') ip.id,
    ];
    expect(b!.supportedIpIds, expected);
  });

  test('every IP id in allIps is unique', () {
    final ids = MarketTaxonomy.allIps.map((e) => e.id).toList();
    expect(ids.toSet().length, ids.length);
  });
}
