import 'dart:convert';

import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/collection/persistence/collection_snapshot_codec.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('encodes catalog-aligned keys for custom shelf rows', () {
    const accent = Color(0xFFE4F2EA);
    final snap = CollectionSnapshot(
      shelfSeries: [
        ShelfSeries(
          id: 'custom-99',
          name: 'Picnic Pals',
          brand: 'Independent',
          ipName: 'Picnic Pals',
          taxonomyBrandId: 'independent',
          taxonomyIpId: 'picnic_pals',
          imageKey: 'custom-99',
          figures: const [
            ShelfFigure(
              id: 'custom-99-f-0',
              seriesId: 'custom-99',
              name: 'Berry',
              imageKey: 'custom-99-f-0',
              localImageUri: '/tmp/berry.png',
              rarity: '1:144',
              rarityLabel: '1:144',
              isSecret: true,
            ),
          ],
          shelfAccent: accent,
          customCoverImageUri: '/tmp/cover.png',
        ),
      ],
      figureStates: const {},
    );

    final json = CollectionSnapshotCodec.encode(snap);
    expect(json, contains('"displayName":"Picnic Pals"'));
    expect(json, contains('"brandId":"independent"'));
    expect(json, contains('"ipId":"picnic_pals"'));
    expect(json, contains('"imageKey":"custom-99-f-0"'));
    expect(json, contains('"rarityLabel":"1:144"'));

    final back = CollectionSnapshotCodec.tryDecode(json)!;
    final series = back.shelfSeries.single;
    expect(series.name, 'Picnic Pals');
    expect(series.taxonomyBrandId, 'independent');
    expect(series.imageKey, 'custom-99');
    final fig = series.figures.single;
    expect(fig.isSecret, isTrue);
    expect(fig.rarityLabel, '1:144');
    expect(fig.imageKey, 'custom-99-f-0');
  });

  test('decodes legacy custom series with name and Custom rarity', () {
    final legacy = jsonEncode({
      'v': 2,
      'shelfSeries': [
        {
          'id': 'custom-old',
          'name': 'Old Set',
          'brand': 'Independent',
          'ipName': 'Old Set',
          'shelfAccentArgb': 0xFFE4F2EA,
          'figures': [
            {
              'id': 'custom-old-f-0',
              'seriesId': 'custom-old',
              'name': 'Fig',
              'rarity': 'Custom',
              'isSecret': false,
            },
          ],
        },
      ],
      'figureStates': {},
    });

    final decoded = CollectionSnapshotCodec.tryDecode(legacy)!;
    final fig = decoded.shelfSeries.single.figures.single;
    expect(fig.name, 'Fig');
    expect(fig.rarity, 'Custom');
    expect(fig.isSecret, isFalse);
    expect(fig.imageKey, 'custom-old-f-0');
  });

  test('migrates legacy ratio in rarity field to rarityLabel', () {
    final legacy = jsonEncode({
      'v': 2,
      'shelfSeries': [
        {
          'id': 's1',
          'name': 'S',
          'brand': 'B',
          'ipName': 'I',
          'shelfAccentArgb': 0xFFE4F2EA,
          'figures': [
            {
              'id': 'f1',
              'seriesId': 's1',
              'name': 'Chase',
              'rarity': '1:72',
              'isSecret': true,
            },
          ],
        },
      ],
      'figureStates': {},
    });

    final fig = CollectionSnapshotCodec.tryDecode(legacy)!.shelfSeries.single.figures.single;
    expect(fig.rarityLabel, '1:72');
    expect(fig.isSecret, isTrue);
  });
}
