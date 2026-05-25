import 'package:blindbox_app/core/theme/app_theme.dart';
import 'package:blindbox_app/features/collection/presentation/shelf_series_feed.dart';
import 'package:blindbox_app/shared/widgets/collectible_section_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'helpers/collection_fixtures.dart';

void main() {
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

    final headers = tester
        .widgetList<CollectibleSectionHeader>(find.byType(CollectibleSectionHeader))
        .map((h) => h.title)
        .toList();
    expect(headers, ['Crybaby', 'Polar']);
  });
}
