import 'package:blindbox_app/features/market/taxonomy/taxonomy_title_normalizer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TaxonomyTitleNormalizer', () {
    test('trims and uppercases ASCII', () {
      expect(
        TaxonomyTitleNormalizer.normalize('  pop mart  '),
        'POP MART',
      );
    });

    test('collapses whitespace and normalizes separators', () {
      expect(
        TaxonomyTitleNormalizer.normalize('a  b\tc·d-e_f/g'),
        'A B C D E F G',
      );
    });

    test('preserves CJK for IP aliases', () {
      expect(
        TaxonomyTitleNormalizer.normalize('  拉布布  series  '),
        '拉布布 SERIES',
      );
    });

    test('empty and whitespace-only become empty', () {
      expect(TaxonomyTitleNormalizer.normalize(''), '');
      expect(TaxonomyTitleNormalizer.normalize('   \t'), '');
    });
  });
}
