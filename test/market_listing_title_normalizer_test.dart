import 'package:blindbox_app/features/market/application/market_listing_title_normalizer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('preserves CJK and uppercases Latin', () {
    final norm = MarketListingTitleNormalizer.normalizeForMatching(
      '拉布布 · labubu chase',
    );
    expect(norm, contains('拉布布'));
    expect(norm, contains('LABUBU'));
  });

  test('strips marketplace noise tokens', () {
    final norm = MarketListingTitleNormalizer.normalizeForMatching(
      'LABUBU V3 SECRET BNIB SEALED',
    );
    expect(norm, contains('LABUBU'));
    expect(norm, contains('SECRET'));
    expect(norm, isNot(contains('BNIB')));
    expect(norm, isNot(contains('V3')));
  });

  test('tokenize removes stopwords', () {
    final tokens = MarketListingTitleNormalizer.tokenize(
      MarketListingTitleNormalizer.normalizeForMatching(
        'THE MONSTERS LABUBU FIGURE',
      ),
    );
    expect(tokens, contains('MONSTERS'));
    expect(tokens, contains('LABUBU'));
    expect(tokens, isNot(contains('THE')));
    expect(tokens, isNot(contains('FIGURE')));
  });
}
