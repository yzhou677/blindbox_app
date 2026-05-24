import 'package:blindbox_app/features/market/application/market_browse_query_composer.dart';
import 'package:blindbox_app/features/market/domain/market_browse_query.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('POP MART + Labubu uses brand q only (verified Character on gateway)', () {
    const query = MarketBrowseQuery(
      brandId: 'pop_mart',
      ipId: 'the_monsters',
    );
    expect(MarketBrowseQueryComposer.composeUpstreamQ(query), 'pop mart');
  });

  test('search macaron with verified IP keeps brand q + search text', () {
    const query = MarketBrowseQuery(
      brandId: 'pop_mart',
      ipId: 'the_monsters',
      searchText: 'macaron',
    );
    expect(
      MarketBrowseQueryComposer.composeUpstreamQ(query),
      'pop mart macaron',
    );
  });

  test('non-verified Dimoo includes IP keyword in q', () {
    const query = MarketBrowseQuery(
      brandId: 'pop_mart',
      ipId: 'dimoo',
    );
    expect(
      MarketBrowseQueryComposer.composeUpstreamQ(query),
      'pop mart Dimoo',
    );
  });

  test('Any brand + Any IP uses discover keywords', () {
    expect(
      MarketBrowseQueryComposer.composeUpstreamQ(const MarketBrowseQuery()),
      'blind box vinyl figure',
    );
  });

  test('generic discover search is anchored', () {
    expect(
      MarketBrowseQueryComposer.composeUpstreamQ(
        const MarketBrowseQuery(searchText: 'baby'),
      ),
      'blind box vinyl figure baby',
    );
  });

  test('taxonomy-native discover search is not over-anchored', () {
    expect(
      MarketBrowseQueryComposer.composeUpstreamQ(
        const MarketBrowseQuery(searchText: 'labubu'),
      ),
      'labubu',
    );
    expect(
      MarketBrowseQueryComposer.composeUpstreamQ(
        const MarketBrowseQuery(searchText: 'sonny angel'),
      ),
      'sonny angel',
    );
  });

  test('brand-filtered search keeps chip context without discover anchor', () {
    expect(
      MarketBrowseQueryComposer.composeUpstreamQ(
        const MarketBrowseQuery(
          brandId: 'pop_mart',
          searchText: 'baby',
        ),
      ),
      'pop mart baby',
    );
  });

  test('signature excludes cursor', () {
    const a = MarketBrowseQuery(cursor: 'abc');
    const b = MarketBrowseQuery(cursor: 'xyz');
    expect(a.signature, b.signature);
  });
}
