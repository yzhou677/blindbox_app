import 'package:blindbox_app/features/collection/data/collection_input_limits.dart';
import 'package:blindbox_app/features/collection/data/collection_input_sanitizer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CollectionInputSanitizer.singleLine / seriesName', () {
    test('trims leading and trailing whitespace', () {
      expect(
        CollectionInputSanitizer.seriesName('  My Series  '),
        'My Series',
      );
    });

    test('collapses repeated internal whitespace', () {
      expect(
        CollectionInputSanitizer.seriesName('   Baby      Three   '),
        'Baby Three',
      );
    });

    test('strips CR and LF', () {
      expect(CollectionInputSanitizer.seriesName('dpl\n'), 'dpl');
      expect(CollectionInputSanitizer.seriesName('Baby\r\nThree'), 'Baby Three');
    });

    test('strips control characters', () {
      expect(
        CollectionInputSanitizer.seriesName('A\u0000B\u0008C'),
        'ABC',
      );
    });

    test('truncates at series name max length', () {
      final raw = 'A' * (CollectionInputLimits.seriesNameMaxLength + 12);
      final out = CollectionInputSanitizer.seriesName(raw);
      expect(out.length, CollectionInputLimits.seriesNameMaxLength);
      expect(out, 'A' * CollectionInputLimits.seriesNameMaxLength);
    });

    test('empty after sanitize returns empty string for seriesName', () {
      expect(CollectionInputSanitizer.seriesName('   \n  '), '');
    });
  });

  group('CollectionInputSanitizer.notes', () {
    test('preserves intentional line breaks', () {
      expect(
        CollectionInputSanitizer.notes('  line one\nline two  '),
        'line one\nline two',
      );
    });

    test('removes control characters', () {
      expect(
        CollectionInputSanitizer.notes('keep\u0000me\nok'),
        'keepme\nok',
      );
    });

    test('truncates at notes max length', () {
      final raw = 'Z' * (CollectionInputLimits.notesMaxLength + 40);
      final out = CollectionInputSanitizer.notes(raw)!;
      expect(out.length, CollectionInputLimits.notesMaxLength);
    });

    test('null for empty notes', () {
      expect(CollectionInputSanitizer.notes('   '), isNull);
    });
  });

  group('field-specific helpers', () {
    test('brand and ip honor their max lengths', () {
      expect(
        CollectionInputSanitizer.brand('x' * 60)!.length,
        CollectionInputLimits.brandMaxLength,
      );
      expect(
        CollectionInputSanitizer.ip('y' * 80)!.length,
        CollectionInputLimits.ipMaxLength,
      );
    });

    test('figure name and rarity honor their max lengths', () {
      expect(
        CollectionInputSanitizer.figureName('f' * 80)!.length,
        CollectionInputLimits.figureNameMaxLength,
      );
      expect(
        CollectionInputSanitizer.rarityLabel('1' * 20)!.length,
        CollectionInputLimits.rarityLabelMaxLength,
      );
    });
  });
}
