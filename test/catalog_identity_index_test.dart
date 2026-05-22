import 'package:blindbox_app/features/market/application/market_listing_title_normalizer.dart';
import 'package:blindbox_app/features/market/data/catalog_identity_index.dart';
import 'support/market_identity_test_bundle.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late CatalogIdentityIndex index;

  setUp(() {
    index = CatalogIdentityIndex.fromBundle(marketIdentityTestBundle());
  });

  test('exact figure name match', () {
    final haystack = MarketListingTitleNormalizer.normalizeForMatching(
      'Labubu Pink sealed',
    );
    final hit = index.bestFigureMatch(haystack);
    expect(hit, isNotNull);
    expect(hit!.figureId, 'fig_labubu_pink');
    expect(hit.tier, CatalogIdentityIndex.tierExactFigure);
  });

  test('secret figure match with substring', () {
    final haystack = MarketListingTitleNormalizer.normalizeForMatching(
      'LABUBU SECRET PINK',
    );
    final hit = index.bestFigureMatch(haystack);
    expect(hit, isNotNull);
    expect(hit!.figureId, 'fig_labubu_secret_pink');
    expect(hit.isSecret, isTrue);
  });

  test('ambiguous series-tier tie returns null figure candidate', () {
    final haystack = MarketListingTitleNormalizer.normalizeForMatching(
      'EXCITING MACARON',
    );
    final hit = index.bestFigureMatch(haystack);
    expect(hit, isNull);
  });
}
