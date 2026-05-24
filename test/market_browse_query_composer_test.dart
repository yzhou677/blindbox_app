import 'package:blindbox_app/features/market/application/market_browse_query_composer.dart';
import 'package:blindbox_app/features/market/domain/market_browse_query.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('POP MART + Labubu uses aspect facets (q empty)', () {
    const query = MarketBrowseQuery(
      brandId: 'pop_mart',
      ipId: 'the_monsters',
    );
    expect(MarketBrowseQueryComposer.composeUpstreamQ(query), '');
  });

  test('search macaron with brand/IP facets keeps only search text', () {
    const query = MarketBrowseQuery(
      brandId: 'pop_mart',
      ipId: 'the_monsters',
      searchText: 'macaron',
    );
    expect(
      MarketBrowseQueryComposer.composeUpstreamQ(query),
      'macaron',
    );
  });

  test('Any brand + Any IP uses aspect facets (q empty)', () {
    expect(
      MarketBrowseQueryComposer.composeUpstreamQ(const MarketBrowseQuery()),
      '',
    );
  });

  test('signature excludes cursor', () {
    const a = MarketBrowseQuery(cursor: 'abc');
    const b = MarketBrowseQuery(cursor: 'xyz');
    expect(a.signature, b.signature);
  });
}
