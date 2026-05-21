import 'dart:convert';

import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/collection/persistence/collection_snapshot_codec.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('CollectionSnapshotCodec round-trip preserves shelf + figure states', () {
    const accent = Color(0xFFE4F2EA);
    final snap = CollectionSnapshot(
      shelfSeries: [
        ShelfSeries(
          id: 'series-a',
          name: 'Test Series',
          brand: 'BRAND',
          ipName: 'IP',
          figures: const [
            ShelfFigure(
              id: 'fig-1',
              seriesId: 'series-a',
              name: 'One',
              localImageUri: '/tmp/fig.png',
              rarity: 'Regular',
              isSecret: false,
              catalogFigureTemplateId: 'tpl-1',
            ),
          ],
          shelfAccent: accent,
          catalogTemplateId: 'catalog-series-x',
          taxonomyBrandId: 'pop_mart',
          taxonomyIpId: 'the_monsters',
          customCoverImageUri: '/tmp/cover.jpg',
        ),
      ],
      figureStates: {
        'fig-1': const TrackedFigure(figureId: 'fig-1', state: FigureCollectionState.wishlist),
      },
    );

    final json = CollectionSnapshotCodec.encode(snap);
    expect(json, contains('"v":2'));
    final back = CollectionSnapshotCodec.tryDecode(json);
    expect(back, isNotNull);
    expect(back!.shelfSeries, hasLength(1));
    expect(back.shelfSeries.single.catalogTemplateId, 'catalog-series-x');
    expect(back.shelfSeries.single.shelfAccent, accent);
    expect(back.shelfSeries.single.customCoverImageUri, '/tmp/cover.jpg');
    expect(back.shelfSeries.single.figures.single.catalogFigureTemplateId, 'tpl-1');
    expect(back.shelfSeries.single.figures.single.localImageUri, '/tmp/fig.png');
    expect(back.figureStates['fig-1']?.state, FigureCollectionState.wishlist);
  });

  test('legacy bool figureStates migrate to enum', () {
    final legacy = jsonEncode({
      'v': 1,
      'shelfSeries': [
        {
          'id': 's1',
          'name': 'N',
          'brand': 'B',
          'ipName': 'I',
          'shelfAccentArgb': 0xFF112233,
          'figures': [
            {
              'id': 'f1',
              'seriesId': 's1',
              'name': 'F',
              'rarity': 'Regular',
              'isSecret': false,
            },
          ],
        },
      ],
      'figureStates': {
        'f1': {'owned': false, 'wishlist': true},
      },
    });

    final decoded = CollectionSnapshotCodec.tryDecode(legacy)!;
    expect(decoded.figureStates['f1']?.state, FigureCollectionState.wishlist);
  });

  test('legacy owned+wishlist becomes owned', () {
    final legacy = jsonEncode({
      'v': 1,
      'shelfSeries': [
        {
          'id': 's1',
          'name': 'N',
          'brand': 'B',
          'ipName': 'I',
          'shelfAccentArgb': 0xFF112233,
          'figures': [
            {
              'id': 'f1',
              'seriesId': 's1',
              'name': 'F',
              'rarity': 'Regular',
              'isSecret': false,
            },
          ],
        },
      ],
      'figureStates': {
        'f1': {'owned': true, 'wishlist': true},
      },
    });

    final decoded = CollectionSnapshotCodec.tryDecode(legacy)!;
    expect(decoded.figureStates['f1']?.state, FigureCollectionState.owned);
  });
}
