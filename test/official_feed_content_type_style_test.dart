import 'package:blindbox_app/features/official_feed/presentation/official_feed_content_type_style.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('resolve assigns distinct accents for known labels', () {
    const scheme = ColorScheme.light();
    final announcement = OfficialFeedContentTypeStyles.resolve(
      'Announcement',
      scheme,
      isDark: false,
    );
    final popNow = OfficialFeedContentTypeStyles.resolve(
      'POP NOW',
      scheme,
      isDark: false,
    );
    final fallback = OfficialFeedContentTypeStyles.resolve(
      'Official update',
      scheme,
      isDark: false,
    );

    expect(announcement.icon, isNotNull);
    expect(popNow.icon, isNotNull);
    expect(announcement.foreground, isNot(equals(popNow.foreground)));
    expect(announcement.background, isNot(equals(fallback.background)));
  });
}
