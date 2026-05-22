import 'package:blindbox_app/features/market/application/market_identity_matcher.dart';
import 'package:blindbox_app/features/market/data/catalog_identity_index.dart';
import 'package:blindbox_app/features/market/domain/market_match_confidence.dart';
import 'support/market_identity_test_bundle.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late MarketIdentityMatcher matcher;

  setUp(() {
    matcher = MarketIdentityMatcher(
      CatalogIdentityIndex.fromBundle(marketIdentityTestBundle()),
    );
  });

  test('LABUBU V3 SECRET maps to secret figure when name is specific', () {
    final m = matcher.match('Labubu Secret Pink chase');
    expect(m.matchedFigureId, 'fig_labubu_secret_pink');
    expect(m.matchedIpId, 'the_monsters');
    expect(m.matchedBrandId, 'pop_mart');
    expect(m.confidence, MarketMatchConfidence.exact);
  });

  test('The Monsters pink hidden prefers conservative low when ambiguous', () {
    final m = matcher.match('The Monsters pink hidden');
    expect(m.matchedFigureId, isNull);
    expect(m.matchedBrandId, 'pop_mart');
    expect(m.confidence, MarketMatchConfidence.low);
  });

  test('unrelated title stays unresolved', () {
    final m = matcher.match('Vintage Toy Lot 1990 Mixed');
    expect(m.confidence, MarketMatchConfidence.none);
    expect(m.matchedFigureId, isNull);
    expect(m.matchedBrandId, isNull);
  });

  test('wire hints constrain without forcing wrong figure', () {
    final m = matcher.match(
      'Random listing text',
      hintBrandId: 'pop_mart',
      hintIpId: 'the_monsters',
    );
    expect(m.matchedBrandId, 'pop_mart');
    expect(m.matchedIpId, 'the_monsters');
    expect(m.normalizationSource, contains('wire_hint'));
  });
}
