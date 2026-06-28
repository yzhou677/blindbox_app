import 'package:blindbox_app/core/theme/app_theme.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/collection/domain/series_completion_atmosphere.dart';
import 'package:blindbox_app/features/collection/presentation/shelf_series_feed.dart';
import 'package:blindbox_app/features/collection/widgets/series_shelf_cards.dart';
import 'package:blindbox_app/shared/widgets/collectible_section_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'helpers/collection_fixtures.dart';

void main() {
  group('shelfIpCollapseSectionKey', () {
    test('scopes collapse prefs per bucket', () {
      expect(
        shelfIpCollapseSectionKey(shelfCollapseBucketInProgress, 'ip:pucky'),
        'in_progress:ip:pucky',
      );
      expect(
        shelfIpCollapseSectionKey(shelfCollapseBucketCompleted, 'ip:pucky'),
        'completed:ip:pucky',
      );
    });
  });

  group('groupShelfSeriesByUniverse', () {
    test('keeps distinct IPs in separate sections', () {
      final sections = groupShelfSeriesByUniverse([
        testShelfSeries(
          id: 'cry_1',
          taxonomyIpId: 'crybaby',
          ipName: 'Crybaby',
        ),
        testShelfSeries(
          id: 'cry_2',
          taxonomyIpId: 'crybaby',
          ipName: 'Crybaby',
        ),
        testShelfSeries(
          id: 'polar_1',
          taxonomyIpId: 'polar',
          ipName: 'Polar',
        ),
      ]);

      expect(sections, hasLength(2));
      expect(sections[0].label, 'Crybaby');
      expect(sections[0].series, hasLength(2));
      expect(sections[1].label, 'Polar');
      expect(sections[1].series, hasLength(1));
    });
  });

  group('shouldShowShelfUniverseHeader', () {
    test('shows header for singleton when multiple universes exist', () {
      expect(
        shouldShowShelfUniverseHeader(
          universeCount: 2,
          seriesInUniverse: 1,
        ),
        isTrue,
      );
    });

    test('hides header for single universe with one series', () {
      expect(
        shouldShowShelfUniverseHeader(
          universeCount: 1,
          seriesInUniverse: 1,
        ),
        isFalse,
      );
    });

    test('shows header for single universe with multiple series', () {
      expect(
        shouldShowShelfUniverseHeader(
          universeCount: 1,
          seriesInUniverse: 3,
        ),
        isTrue,
      );
    });
  });

  testWidgets('buildShelfSeriesFeed labels orphan singleton universe', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Builder(
          builder: (context) => Scaffold(
            body: ListView(
              children: buildShelfSeriesFeed(
                context: context,
                series: [
                testShelfSeries(
                  id: 'cry_1',
                  taxonomyIpId: 'crybaby',
                  ipName: 'Crybaby',
                ),
                testShelfSeries(
                  id: 'cry_2',
                  taxonomyIpId: 'crybaby',
                  ipName: 'Crybaby',
                ),
                testShelfSeries(
                  id: 'polar_1',
                  taxonomyIpId: 'polar',
                  ipName: 'Polar',
                ),
              ],
              figureStates: const {},
                onOpen: (_) {},
                onRemove: (_) {},
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Polar'), findsAtLeastNWidgets(1));
    expect(find.text('Crybaby'), findsAtLeastNWidgets(1));
  });

  // ---------------------------------------------------------------------------
  // buildShelfFeedItems — lazy flat-list data model
  // ---------------------------------------------------------------------------

  testWidgets('buildShelfFeedItems returns empty list for empty series', (
    tester,
  ) async {
    late List<ShelfFeedItem> items;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Builder(
          builder: (context) {
            items = buildShelfFeedItems(
              context: context,
              series: const [],
              figureStates: const {},
            );
            return const SizedBox();
          },
        ),
      ),
    );
    expect(items, isEmpty);
  });

  testWidgets('buildShelfFeedItems produces one ShelfFeedCard per series', (
    tester,
  ) async {
    late List<ShelfFeedItem> items;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Builder(
          builder: (context) {
            items = buildShelfFeedItems(
              context: context,
              series: [
                testShelfSeries(id: 's1', taxonomyIpId: 'ip_a', ipName: 'A'),
                testShelfSeries(id: 's2', taxonomyIpId: 'ip_a', ipName: 'A'),
                testShelfSeries(id: 's3', taxonomyIpId: 'ip_b', ipName: 'B'),
              ],
              figureStates: const {},
            );
            return const SizedBox();
          },
        ),
      ),
    );

    final cards = items.whereType<ShelfFeedCard>().toList();
    expect(cards, hasLength(3));
    expect(cards.map((c) => c.series.id).toList(), ['s1', 's2', 's3']);
  });

  testWidgets(
    'buildShelfFeedItems emits ShelfFeedHeader for multi-universe shelf',
    (tester) async {
      late List<ShelfFeedItem> items;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Builder(
            builder: (context) {
              items = buildShelfFeedItems(
                context: context,
                series: [
                  testShelfSeries(id: 's1', taxonomyIpId: 'ip_a', ipName: 'A'),
                  testShelfSeries(id: 's2', taxonomyIpId: 'ip_b', ipName: 'B'),
                ],
                figureStates: const {},
              );
              return const SizedBox();
            },
          ),
        ),
      );

      final headers = items.whereType<ShelfFeedHeader>().toList();
      expect(headers, hasLength(2));
      expect(headers[0].label, 'A');
      expect(headers[1].label, 'B');
    },
  );

  testWidgets(
    'buildShelfFeedItems emits ShelfFeedGap instead of header for second '
    'section when single-series universe with no peers',
    (tester) async {
      // Single universe, 3 series → header + 3 cards (no gap needed).
      late List<ShelfFeedItem> items;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Builder(
            builder: (context) {
              items = buildShelfFeedItems(
                context: context,
                series: [
                  testShelfSeries(id: 's1', taxonomyIpId: 'ip_a', ipName: 'A'),
                  testShelfSeries(id: 's2', taxonomyIpId: 'ip_a', ipName: 'A'),
                  testShelfSeries(id: 's3', taxonomyIpId: 'ip_a', ipName: 'A'),
                ],
                figureStates: const {},
              );
              return const SizedBox();
            },
          ),
        ),
      );

      expect(items.whereType<ShelfFeedHeader>(), hasLength(1));
      expect(items.whereType<ShelfFeedCard>(), hasLength(3));
    },
  );

  testWidgets(
    'buildShelfFeedItems item count equals sections + cards consistently',
    (tester) async {
      late List<ShelfFeedItem> items;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Builder(
            builder: (context) {
              items = buildShelfFeedItems(
                context: context,
                series: [
                  testShelfSeries(id: 'a1', taxonomyIpId: 'ia', ipName: 'A'),
                  testShelfSeries(id: 'a2', taxonomyIpId: 'ia', ipName: 'A'),
                  testShelfSeries(id: 'b1', taxonomyIpId: 'ib', ipName: 'B'),
                  testShelfSeries(id: 'c1', taxonomyIpId: 'ic', ipName: 'C'),
                ],
                figureStates: const {},
              );
              return const SizedBox();
            },
          ),
        ),
      );

      final cardCount = items.whereType<ShelfFeedCard>().length;
      final headerCount = items.whereType<ShelfFeedHeader>().length;
      final gapCount = items.whereType<ShelfFeedGap>().length;
      // 4 cards total; 3 universe headers (A, B, C); no gap items since each
      // section has an explicit header (multi-universe).
      expect(cardCount, 4);
      expect(headerCount, 3);
      expect(gapCount, 0);
    },
  );

  testWidgets(
    'buildShelfFeedItemWidget renders SeriesShelfCard for ShelfFeedCard',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: Builder(
              builder: (context) {
                final item = ShelfFeedCard(
                  sectionColor: Colors.white,
                  series: testShelfSeries(id: 'x1'),
                  progress: const SeriesProgressCounts(
                    owned: 0,
                    wishlist: 0,
                    missing: 0,
                  ),
                  figureStates: const {},
                  atmosphere: const SeriesCompletionAtmosphere(),
                );
                return buildShelfFeedItemWidget(
                  context: context,
                  item,
                  onOpen: (_) {},
                  onRemove: (_) {},
                );
              },
            ),
          ),
        ),
      );

      expect(find.byType(SeriesShelfCard), findsOneWidget);
    },
  );

  testWidgets(
    'buildShelfFeedItems still shows cards when collapsed but header hidden',
    (tester) async {
      late List<ShelfFeedItem> items;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Builder(
            builder: (context) {
              items = buildShelfFeedItems(
                context: context,
                series: [
                  testShelfSeries(id: 'solo', taxonomyIpId: 'ia', ipName: 'A'),
                ],
                figureStates: const {},
                collapsedSectionKeys: {'ip:ia'},
              );
              return const SizedBox();
            },
          ),
        ),
      );

      expect(items.whereType<ShelfFeedHeader>(), isEmpty);
      expect(items.whereType<ShelfFeedCard>(), hasLength(1));
    },
  );

  testWidgets('buildShelfFeedItems omits cards for collapsed IP sections', (
    tester,
  ) async {
    late List<ShelfFeedItem> items;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Builder(
          builder: (context) {
            items = buildShelfFeedItems(
              context: context,
              series: [
                testShelfSeries(id: 'a1', taxonomyIpId: 'ia', ipName: 'A'),
                testShelfSeries(id: 'a2', taxonomyIpId: 'ia', ipName: 'A'),
                testShelfSeries(id: 'b1', taxonomyIpId: 'ib', ipName: 'B'),
              ],
              figureStates: const {},
              collapseBucketKey: shelfCollapseBucketInProgress,
              collapsedSectionKeys: {
                shelfIpCollapseSectionKey(shelfCollapseBucketInProgress, 'ip:ia'),
              },
            );
            return const SizedBox();
          },
        ),
      ),
    );

    expect(items.whereType<ShelfFeedHeader>(), hasLength(2));
    expect(items.whereType<ShelfFeedCard>(), hasLength(1));
    expect(items.whereType<ShelfFeedCard>().single.series.id, 'b1');
  });

  testWidgets(
    'buildShelfFeedItems keeps bucket collapse independent for same IP',
    (tester) async {
      final puckySeries = [
        testShelfSeries(id: 'p1', taxonomyIpId: 'pucky', ipName: 'Pucky'),
        testShelfSeries(id: 'p2', taxonomyIpId: 'pucky', ipName: 'Pucky'),
      ];

      late List<ShelfFeedItem> inProgressItems;
      late List<ShelfFeedItem> completedItems;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Builder(
            builder: (context) {
              final collapsed = {
                shelfIpCollapseSectionKey(
                  shelfCollapseBucketInProgress,
                  'ip:pucky',
                ),
              };
              inProgressItems = buildShelfFeedItems(
                context: context,
                series: puckySeries,
                figureStates: const {},
                collapseBucketKey: shelfCollapseBucketInProgress,
                collapsedSectionKeys: collapsed,
              );
              completedItems = buildShelfFeedItems(
                context: context,
                series: puckySeries,
                figureStates: const {},
                collapseBucketKey: shelfCollapseBucketCompleted,
                collapsedSectionKeys: collapsed,
              );
              return const SizedBox();
            },
          ),
        ),
      );

      expect(inProgressItems.whereType<ShelfFeedCard>(), isEmpty);
      expect(completedItems.whereType<ShelfFeedCard>(), hasLength(2));
    },
  );
}
