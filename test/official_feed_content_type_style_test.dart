import 'package:blindbox_app/features/official_feed/presentation/official_feed_content_type.dart';
import 'package:blindbox_app/features/official_feed/presentation/official_feed_content_type_style.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('resolve assigns distinct accents for known labels', () {
    const scheme = ColorScheme.light();
    final announcement = OfficialFeedContentTypeStyles.resolve(
      OfficialFeedContentTags.announcement,
      scheme,
      isDark: false,
    );
    final popNow = OfficialFeedContentTypeStyles.resolve(
      OfficialFeedContentTags.popNow,
      scheme,
      isDark: false,
    );
    final comingSoon = OfficialFeedContentTypeStyles.resolve(
      OfficialFeedContentTags.comingSoon,
      scheme,
      isDark: false,
    );
    final fallback = OfficialFeedContentTypeStyles.resolve(
      OfficialFeedContentTags.officialUpdate,
      scheme,
      isDark: false,
    );

    expect(announcement.icon, isNotNull);
    expect(popNow.icon, isNotNull);
    expect(comingSoon.icon, isNotNull);
    expect(announcement.foreground, isNot(equals(popNow.foreground)));
    expect(announcement.background, isNot(equals(fallback.background)));
  });

  test('legacy Campaign and Launch Reminder resolve via neutral fallback', () {
    const scheme = ColorScheme.light();
    final campaign = OfficialFeedContentTypeStyles.resolve(
      'Campaign',
      scheme,
      isDark: false,
    );
    final reminder = OfficialFeedContentTypeStyles.resolve(
      'Launch Reminder',
      scheme,
      isDark: false,
    );
    final officialUpdate = OfficialFeedContentTypeStyles.resolve(
      OfficialFeedContentTags.officialUpdate,
      scheme,
      isDark: false,
    );

    expect(campaign.foreground, officialUpdate.foreground);
    expect(reminder.foreground, officialUpdate.foreground);
  });
}
