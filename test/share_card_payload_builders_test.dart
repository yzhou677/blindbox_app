import 'package:blindbox_app/features/collection/application/share_payload_builders/master_complete_share_payload_builder.dart';
import 'package:blindbox_app/features/collection/application/share_payload_builders/share_card_series_label.dart';
import 'package:blindbox_app/features/collection/application/share_payload_builders/shelf_share_featured_series_selector.dart';
import 'package:blindbox_app/features/collection/application/share_payload_builders/shelf_share_payload_builder.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/collection_fixtures.dart';

ShelfSeries _series({
  required String id,
  required String name,
  int regular = 2,
  int secret = 1,
  String? imageKey,
}) {
  return testShelfSeries(
    id: id,
    name: name,
    imageKey: imageKey ?? id,
    figures: [
      for (var i = 0; i < regular; i++)
        ShelfFigure(
          id: '${id}_r$i',
          seriesId: id,
          name: 'Regular $i',
          rarity: 'Regular',
          isSecret: false,
        ),
      for (var i = 0; i < secret; i++)
        ShelfFigure(
          id: '${id}_s$i',
          seriesId: id,
          name: 'Secret $i',
          rarity: 'Secret',
          isSecret: true,
        ),
    ],
  );
}

Map<String, TrackedFigure> _owned(Iterable<String> ids) {
  return {
    for (final id in ids)
      id: TrackedFigure(figureId: id, state: FigureCollectionState.owned),
  };
}

void main() {
  group('shareCardSeriesLabel', () {
    test('removes catalog-style product suffixes', () {
      expect(
        shareCardSeriesLabel(
          'DIMOO WORLD × PIXAR Series - Vinyl Plush Blind Box',
        ),
        'DIMOO WORLD × PIXAR',
      );
      expect(
        shareCardSeriesLabel(
          'MOLLY The Wheel of Time 20th Anniversary Series Figures',
        ),
        'MOLLY The Wheel of Time 20th Anniversary',
      );
      expect(
        shareCardSeriesLabel(
          'Hannibal The Apéritif Collection Titans Blind Box Figure',
        ),
        'Hannibal The Apéritif',
      );
    });

    test('uppercases only after shortening', () {
      expect(
        shareCardSeriesLabel('Exciting Macaron Series', uppercase: true),
        'EXCITING MACARON',
      );
    });
  });

  group('selectShelfShareFeaturedSeries', () {
    test('prioritizes master, completed, then highest regular progress', () {
      final master = _series(id: 'master', name: 'Z Master');
      final complete = _series(id: 'complete', name: 'A Complete');
      final near = _series(id: 'near', name: 'Near', regular: 4);
      final low = _series(id: 'low', name: 'Low', regular: 4);
      final snap = CollectionSnapshot(
        shelfSeries: [low, near, complete, master],
        figureStates: {
          ..._owned(['master_r0', 'master_r1', 'master_s0']),
          ..._owned(['complete_r0', 'complete_r1']),
          ..._owned(['near_r0', 'near_r1', 'near_r2']),
          ..._owned(['low_r0']),
        },
      );

      final selected = selectShelfShareFeaturedSeries(snap);

      expect(selected.map((s) => s.id), ['master', 'complete', 'near', 'low']);
    });

    test('uses shelf encounter order when tier and progress tie', () {
      final a = _series(id: 'a', name: 'Zed', regular: 4);
      final b = _series(id: 'b', name: 'Alpha', regular: 4);
      final snap = CollectionSnapshot(
        shelfSeries: [a, b],
        figureStates: {
          ..._owned(['a_r0', 'a_r1']),
          ..._owned(['b_r0', 'b_r1']),
        },
      );

      final selected = selectShelfShareFeaturedSeries(snap);

      expect(selected.map((s) => s.id), ['a', 'b']);
    });

    test('caps at six series', () {
      final series = [
        for (var i = 0; i < 8; i++) _series(id: 's$i', name: 'Series $i'),
      ];
      final snap = CollectionSnapshot(shelfSeries: series, figureStates: {});

      expect(selectShelfShareFeaturedSeries(snap), hasLength(6));
    });
  });

  group('buildMasterCompleteSharePayload', () {
    test('returns null for regular-complete series missing a secret', () {
      final series = _series(id: 'm', name: 'Macaron');
      final payload = buildMasterCompleteSharePayload(
        series: series,
        figureStates: _owned(['m_r0', 'm_r1']),
      );

      expect(payload, isNull);
    });

    test('builds metadata from canonical master completion math', () {
      final series = _series(id: 'm', name: 'Exciting Macaron');
      final payload = buildMasterCompleteSharePayload(
        series: series,
        figureStates: _owned(['m_r0', 'm_r1', 'm_s0']),
      );

      expect(payload, isNotNull);
      expect(payload!.metadata, 'REGULAR 2/2 · SECRET 1/1');
      expect(payload.seriesName, 'EXCITING MACARON');
    });
  });

  group('buildShelfSharePayload', () {
    test('uses aggregate shelf progress and featured selection', () {
      final master = _series(id: 'master', name: 'Master');
      final open = _series(id: 'open', name: 'Open', regular: 4);
      final snap = CollectionSnapshot(
        shelfSeries: [open, master],
        figureStates: {
          ..._owned(['master_r0', 'master_r1', 'master_s0']),
          ..._owned(['open_r0', 'open_r1']),
        },
      );

      final payload = buildShelfSharePayload(
        snapshot: snap,
        generatedAt: DateTime(2026),
      );

      expect(payload.overallRegularProgress, 75);
      expect(payload.masterCompleteSeriesCount, 1);
      expect(payload.featuredSeries.map((s) => s.seriesId), ['master', 'open']);
    });
  });
}
