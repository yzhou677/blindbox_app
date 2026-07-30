import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/ip_profile/presentation/ip_introduction_ownership.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/collection_fixtures.dart';

void main() {
  group('resolveIpIntroductionIpSeriesCount', () {
    test('counts all shelf series sharing the profile ipId', () {
      final snap = CollectionSnapshot(
        shelfSeries: [
          testShelfSeries(
            id: 'a',
            catalogTemplateId: 'cat_a',
            taxonomyIpId: 'molly',
            name: 'Molly A',
          ),
          testShelfSeries(
            id: 'b',
            catalogTemplateId: 'cat_b',
            taxonomyIpId: 'molly',
            name: 'Molly B',
          ),
          testShelfSeries(
            id: 'c',
            catalogTemplateId: 'cat_c',
            taxonomyIpId: 'hirono',
            name: 'Hirono',
          ),
        ],
        figureStates: const {},
      );
      final count = resolveIpIntroductionIpSeriesCount(
        ipId: 'molly',
        snapshot: snap,
      );
      expect(count?.seriesCount, 2);
      expect(count?.seriesLine, '2 series');
    });

    test('excludes series belonging to other IPs', () {
      final snap = CollectionSnapshot(
        shelfSeries: [
          testShelfSeries(
            id: 'a',
            catalogTemplateId: 'cat_a',
            taxonomyIpId: 'skullpanda',
          ),
        ],
        figureStates: const {},
      );
      expect(
        resolveIpIntroductionIpSeriesCount(ipId: 'molly', snapshot: snap),
        isNull,
      );
    });

    test('never matches by display name or series title', () {
      final snap = CollectionSnapshot(
        shelfSeries: [
          testShelfSeries(
            id: 'a',
            catalogTemplateId: 'cat_a',
            taxonomyIpId: 'hirono',
            name: 'MOLLY',
            ipName: 'MOLLY',
            brand: 'POP MART',
          ),
        ],
        figureStates: const {},
      );
      expect(
        resolveIpIntroductionIpSeriesCount(ipId: 'MOLLY', snapshot: snap),
        isNull,
      );
      expect(
        resolveIpIntroductionIpSeriesCount(ipId: 'molly', snapshot: snap),
        isNull,
      );
    });

    test(
      'deduplicates duplicate representations of the same stable series',
      () {
        final snap = CollectionSnapshot(
          shelfSeries: [
            testShelfSeries(
              id: 'shelf_1',
              catalogTemplateId: 'series-molly-childhood',
              taxonomyIpId: 'molly',
            ),
            // Drop-prefixed import of the same catalog series.
            testShelfSeries(
              id: 'shelf_2',
              catalogTemplateId: 'drop-series-molly-childhood',
              taxonomyIpId: 'molly',
            ),
          ],
          figureStates: const {},
        );
        final count = resolveIpIntroductionIpSeriesCount(
          ipId: 'molly',
          snapshot: snap,
        );
        expect(count?.seriesCount, 1);
        expect(count?.seriesLine, '1 series');
      },
    );

    test('excludes custom series without a matching taxonomyIpId', () {
      final custom = ShelfSeries(
        id: 'custom_1',
        name: 'My Molly Shelf',
        brand: 'POP MART',
        ipName: 'MOLLY',
        figures: const [],
        shelfAccent: const Color(0xFFCCCCCC),
        catalogTemplateId: null,
        taxonomyIpId: null,
      );
      final snap = CollectionSnapshot(
        shelfSeries: [
          custom,
          testShelfSeries(
            id: 'a',
            catalogTemplateId: 'cat_a',
            taxonomyIpId: 'molly',
          ),
        ],
        figureStates: const {},
      );
      final count = resolveIpIntroductionIpSeriesCount(
        ipId: 'molly',
        snapshot: snap,
      );
      expect(count?.seriesCount, 1);
    });

    test('empty collection and zero matches return null (omit section)', () {
      expect(
        resolveIpIntroductionIpSeriesCount(
          ipId: 'molly',
          snapshot: const CollectionSnapshot(shelfSeries: [], figureStates: {}),
        ),
        isNull,
      );
    });

    test('empty ipId returns null', () {
      final snap = CollectionSnapshot(
        shelfSeries: [
          testShelfSeries(
            id: 'a',
            catalogTemplateId: 'cat_a',
            taxonomyIpId: 'molly',
          ),
        ],
        figureStates: const {},
      );
      expect(
        resolveIpIntroductionIpSeriesCount(ipId: '  ', snapshot: snap),
        isNull,
      );
    });
  });
}
