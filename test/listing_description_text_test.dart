import 'package:blindbox_app/features/market/utils/listing_description_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('sanitizeListingDescription', () {
    test('returns null for null, empty, and whitespace-only', () {
      expect(sanitizeListingDescription(null), isNull);
      expect(sanitizeListingDescription(''), isNull);
      expect(sanitizeListingDescription('   \n\t  '), isNull);
    });

    test('strips HTML tags and collapses whitespace', () {
      expect(
        sanitizeListingDescription(
          '<p>Pop Mart <b>Labubu</b></p>\n\n&nbsp;sealed',
        ),
        'Pop Mart Labubu sealed',
      );
    });

    test('decodes common HTML entities', () {
      expect(
        sanitizeListingDescription('Molly &amp; friends &mdash; new'),
        'Molly & friends — new',
      );
    });

    test('handles malformed input without throwing', () {
      expect(
        sanitizeListingDescription('<unclosed> still readable'),
        'still readable',
      );
    });
  });

  group('listingDescriptionExceedsCollapsedLines', () {
    const style = TextStyle(fontSize: 14, height: 1.35);
    const direction = TextDirection.ltr;

    test('short copy does not exceed collapsed lines', () {
      expect(
        listingDescriptionExceedsCollapsedLines(
          text: 'Short listing note.',
          style: style,
          maxWidth: 360,
          maxLines: 5,
          textDirection: direction,
        ),
        isFalse,
      );
    });

    test('long copy exceeds collapsed lines', () {
      final long = List.filled(80, 'word').join(' ');
      expect(
        listingDescriptionExceedsCollapsedLines(
          text: long,
          style: style,
          maxWidth: 360,
          maxLines: 5,
          textDirection: direction,
        ),
        isTrue,
      );
    });
  });
}
