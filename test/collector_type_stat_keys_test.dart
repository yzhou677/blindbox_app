import 'package:blindbox_app/features/collection/insights/application/collector_type_stat_keys.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('canonicalizeStatKey', () {
    test('normalizes POP MART variants', () {
      expect(canonicalizeStatKey('POP MART'), 'popmart');
      expect(canonicalizeStatKey('Popmart'), 'popmart');
      expect(canonicalizeStatKey('pop_mart'), 'popmart');
      expect(canonicalizeStatKey('pop-mart'), 'popmart');
      expect(canonicalizeStatKey('  POP-MART  '), 'popmart');
    });

    test('empty after trim returns empty', () {
      expect(canonicalizeStatKey('   '), '');
    });
  });

  group('aggregateBrandBreakdownByCanonicalKey', () {
    test('merges variant keys under one display label', () {
      final breakdown = aggregateBrandBreakdownByCanonicalKey([
        (displayLabel: 'POP MART', rawKey: 'pop_mart'),
        (displayLabel: 'Popmart', rawKey: 'POP MART'),
        (displayLabel: 'pop-mart', rawKey: 'pop-mart'),
      ]);
      expect(breakdown.length, 1);
      expect(breakdown['POP MART'], 3);
    });

    test('keeps distinct canonical brands separate', () {
      final breakdown = aggregateBrandBreakdownByCanonicalKey([
        (displayLabel: 'POP MART', rawKey: 'pop_mart'),
        (displayLabel: 'Finding Unicorn', rawKey: 'finding_unicorn'),
      ]);
      expect(breakdown.length, 2);
      expect(breakdown['POP MART'], 1);
      expect(breakdown['Finding Unicorn'], 1);
    });
  });
}
