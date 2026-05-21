import 'package:blindbox_app/features/market/taxonomy/taxonomy_resolver.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const resolver = TitleTaxonomyResolver();

  group('TitleTaxonomyResolver', () {
    test('POP MART + Labubu via THE MONSTERS alias', () {
      final m = resolver.resolve(
        'POP MART THE MONSTERS LABUBU Exciting Macaron — sealed',
      );
      expect(m.brandId, 'pop_mart');
      expect(m.ipId, 'the_monsters');
      expect(m.confidence, TitleTaxonomyResolver.confidenceIp);
    });

    test('SonnyAngel → Dreams + Sonny Angel', () {
      final m = resolver.resolve('SonnyAngel Christmas Series');
      expect(m.brandId, 'dreams_inc');
      expect(m.ipId, 'sonny_angel');
      expect(m.confidence, TitleTaxonomyResolver.confidenceIp);
    });

    test('Nommi in title → TOPTOY + nommi', () {
      final m = resolver.resolve('Nommi · Metro Ghost chase');
      expect(m.brandId, 'toptoy');
      expect(m.ipId, 'nommi');
    });

    test('weak unrelated title → unknown taxonomy match', () {
      final m = resolver.resolve('Vintage Toy Lot 1990 Mixed Figures');
      expect(m.brandId, isNull);
      expect(m.ipId, isNull);
      expect(m.confidence, 0);
    });

    test('ambiguous IP tie → falls back to brand-only when brand is clear', () {
      final m = resolver.resolve('POP MART X MOLLY DIMOO');
      expect(m.ipId, isNull);
      expect(m.brandId, 'pop_mart');
      expect(m.confidence, TitleTaxonomyResolver.confidenceBrandOnly);
    });

    test('ambiguous IP tie without brand string → unknown', () {
      final m = resolver.resolve('MOLLY VS DIMOO');
      expect(m.brandId, isNull);
      expect(m.ipId, isNull);
    });

    test('Skullpanda vs TNTSPACE substring lengths prefer longer IP alias', () {
      final m = resolver.resolve('Skullpanda × TNTSPACE · Neon drift');
      expect(m.ipId, 'skullpanda');
      expect(m.brandId, 'pop_mart');
    });

    test('CJK Labubu alias still matches', () {
      final m = resolver.resolve('POPMART 拉布布 限定');
      expect(m.ipId, 'the_monsters');
      expect(m.brandId, 'pop_mart');
    });
  });
}
