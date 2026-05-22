import 'package:blindbox_app/features/home/data/home_drop_rail_context.dart';
import 'package:blindbox_app/models/collectible.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('HomeDropRailContext.homeReleaseWindowLabel', () {
    test('past within 21 days → Recently added', () {
      final clock = DateTime(2026, 5, 13);
      final r = DateTime(2026, 5, 1);
      expect(
        HomeDropRailContext.homeReleaseWindowLabel(r, clock: clock),
        'Recently added',
      );
    });

    test('past same month but >21 days → month releases', () {
      final clock = DateTime(2026, 4, 28);
      final r = DateTime(2026, 4, 1);
      expect(
        HomeDropRailContext.homeReleaseWindowLabel(r, clock: clock),
        'April releases',
      );
    });

    test('past earlier month same year → month releases (no seasonal label)', () {
      final clock = DateTime(2026, 4, 15);
      final r = DateTime(2026, 3, 10);
      expect(
        HomeDropRailContext.homeReleaseWindowLabel(r, clock: clock),
        'March releases',
      );
    });

    test('past different month same year → month releases', () {
      final clock = DateTime(2026, 4, 15);
      final r = DateTime(2026, 2, 20);
      expect(
        HomeDropRailContext.homeReleaseWindowLabel(r, clock: clock),
        'February releases',
      );
    });

    test('future same month → This month', () {
      final clock = DateTime(2026, 4, 15);
      final r = DateTime(2026, 4, 28);
      expect(
        HomeDropRailContext.homeReleaseWindowLabel(r, clock: clock),
        'This month',
      );
    });

    test('future other month same year → month releases', () {
      final clock = DateTime(2026, 4, 15);
      final r = DateTime(2026, 6, 1);
      expect(
        HomeDropRailContext.homeReleaseWindowLabel(r, clock: clock),
        'June releases',
      );
    });

    test('past other year includes year', () {
      final clock = DateTime(2026, 5, 13);
      final r = DateTime(2025, 8, 1);
      expect(
        HomeDropRailContext.homeReleaseWindowLabel(r, clock: clock),
        'August 2025 releases',
      );
    });
  });

  test('recentReleasesRailCaption is stable copy', () {
    expect(
      HomeDropRailContext.recentReleasesRailCaption,
      'Recent releases',
    );
  });

  group('HomeDropRailContext.latestDropsRailCaption', () {
    test('newest in current month (past) → New this month', () {
      final clock = DateTime(2026, 5, 13);
      final items = [
        Collectible(
          id: 'a',
          name: 'A',
          series: 'S',
          brand: 'B',
          releaseDate: DateTime(2026, 5, 10),
          imageUrl: 'https://example.com/a.png',
        ),
      ];
      expect(
        HomeDropRailContext.latestDropsRailCaption(items, clock: clock),
        'New this month',
      );
    });

    test('uses month label of newest item when not current month', () {
      final clock = DateTime(2026, 5, 13);
      final items = [
        Collectible(
          id: 'a',
          name: 'A',
          series: 'S',
          brand: 'B',
          releaseDate: DateTime(2026, 3, 1),
          imageUrl: 'https://example.com/a.png',
        ),
        Collectible(
          id: 'b',
          name: 'B',
          series: 'S',
          brand: 'B',
          releaseDate: DateTime(2026, 4, 12),
          imageUrl: 'https://example.com/b.png',
        ),
      ];
      expect(
        HomeDropRailContext.latestDropsRailCaption(items, clock: clock),
        'April releases',
      );
    });
  });
}
