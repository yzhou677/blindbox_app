import 'package:blindbox_app/features/collection/insights/application/collector_type_reveal_age.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 6, 26, 12);

  test('today', () {
    expect(
      formatCollectorTypeUpdatedLabel(
        revealedAt: DateTime(2026, 6, 26, 8),
        now: now,
      ),
      'Updated today',
    );
  });

  test('yesterday', () {
    expect(
      formatCollectorTypeUpdatedLabel(
        revealedAt: DateTime(2026, 6, 25, 12),
        now: now,
      ),
      'Updated yesterday',
    );
  });

  test('days ago', () {
    expect(
      formatCollectorTypeUpdatedLabel(
        revealedAt: DateTime(2026, 6, 23, 12),
        now: now,
      ),
      'Updated 3 days ago',
    );
  });

  test('future reveal returns null', () {
    expect(
      formatCollectorTypeUpdatedLabel(
        revealedAt: now.add(const Duration(days: 2)),
        now: now,
      ),
      isNull,
    );
  });
}
