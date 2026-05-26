import 'package:blindbox_app/features/official_feed/presentation/official_feed_relative_time.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('formatOfficialFeedRelativeTime uses compact units', () {
    final clock = DateTime(2026, 5, 20, 12);
    expect(
      formatOfficialFeedRelativeTime(
        clock.subtract(const Duration(minutes: 3)),
        clock: clock,
      ),
      '3m ago',
    );
    expect(
      formatOfficialFeedRelativeTime(
        clock.subtract(const Duration(hours: 5)),
        clock: clock,
      ),
      '5h ago',
    );
    expect(
      formatOfficialFeedRelativeTime(
        clock.subtract(const Duration(days: 2)),
        clock: clock,
      ),
      '2d ago',
    );
    expect(
      formatOfficialFeedRelativeTime(
        DateTime(2026, 3, 18),
        clock: clock,
      ),
      'Mar 18',
    );
    expect(
      formatOfficialFeedRelativeTime(
        clock.subtract(const Duration(seconds: 30)),
        clock: clock,
      ),
      'Now',
    );
  });
}
