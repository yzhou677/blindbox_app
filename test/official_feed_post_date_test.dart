import 'package:blindbox_app/features/official_feed/presentation/official_feed_post_date.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('formatOfficialFeedPostDate uses local calendar day', () {
    // IG post 2026-07-03T08:52:21Z ≈ Jul 3 early morning US — not Jul 2.
    final localPostTime = DateTime.utc(2026, 7, 3, 8, 52, 21).toLocal();
    expect(formatOfficialFeedPostDate(localPostTime), 'Jul 3');
  });

  test('midnight UTC alone would show wrong US day without full post time', () {
    final truncatedMidnightUtc = DateTime.utc(2026, 7, 3).toLocal();
    final fullPostTime = DateTime.utc(2026, 7, 3, 8, 52, 21).toLocal();
    // Document why seed must store full post instant, not T00:00:00Z.
    if (truncatedMidnightUtc.day != fullPostTime.day) {
      expect(formatOfficialFeedPostDate(truncatedMidnightUtc), isNot('Jul 3'));
    }
    expect(formatOfficialFeedPostDate(fullPostTime), 'Jul 3');
  });
}
