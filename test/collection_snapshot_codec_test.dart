import 'dart:convert';

import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/collection/persistence/collection_snapshot_codec.dart';
import 'package:blindbox_app/features/collection/persistence/collection_snapshot_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'CollectionSnapshotCodec round-trip preserves shelf + figure states',
    () {
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
          'fig-1': const TrackedFigure(
            figureId: 'fig-1',
            state: FigureCollectionState.wishlist,
            updatedAtMicros: 123,
          ),
        },
        seriesWishlist: const [
          WishlistedCatalogSeries(
            catalogSeriesId: 'catalog-series-y',
            name: 'Future Series',
            brand: 'BRAND',
            ipName: 'IP',
            imageKey: 'future-key',
            addedAtMicros: 456,
          ),
        ],
      );

      final json = CollectionSnapshotCodec.encode(snap);
      expect(json, contains('"v":3'));
      final back = CollectionSnapshotCodec.tryDecode(json);
      expect(back, isNotNull);
      expect(back!.shelfSeries, hasLength(1));
      expect(back.shelfSeries.single.catalogTemplateId, 'catalog-series-x');
      expect(back.shelfSeries.single.shelfAccent, accent);
      expect(back.shelfSeries.single.customCoverImageUri, '/tmp/cover.jpg');
      expect(
        back.shelfSeries.single.figures.single.catalogFigureTemplateId,
        'tpl-1',
      );
      expect(
        back.shelfSeries.single.figures.single.localImageUri,
        '/tmp/fig.png',
      );
      expect(back.figureStates['fig-1']?.state, FigureCollectionState.wishlist);
      expect(back.figureStates['fig-1']?.updatedAtMicros, 123);
      expect(back.seriesWishlist.single.catalogSeriesId, 'catalog-series-y');
      expect(back.seriesWishlist.single.addedAtMicros, 456);
    },
  );

  test(
    'series wishlist entries already in collection are dropped on decode',
    () {
      final raw = jsonEncode({
        'v': 3,
        'shelfSeries': [
          {
            'id': 's1',
            'name': 'N',
            'brand': 'B',
            'ipName': 'I',
            'catalogTemplateId': 'cat-1',
            'shelfAccentArgb': 0xFF112233,
            'figures': const [],
          },
        ],
        'figureStates': const {},
        'seriesWishlist': [
          {
            'catalogSeriesId': 'cat-1',
            'name': 'N',
            'brand': 'B',
            'ipName': 'I',
            'imageKey': 'cat-1',
            'addedAtMicros': 1,
          },
          {
            'catalogSeriesId': 'cat-2',
            'name': 'M',
            'brand': 'B',
            'ipName': 'I',
            'imageKey': 'cat-2',
            'addedAtMicros': 2,
          },
        ],
      });

      final decoded = CollectionSnapshotCodec.tryDecode(raw)!;
      expect(decoded.seriesWishlist.map((s) => s.catalogSeriesId), ['cat-2']);
    },
  );

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

  test('old snapshot without seriesWishlist decodes safely', () {
    final legacy = jsonEncode({
      'v': 2,
      'shelfSeries': [
        {
          'id': 's1',
          'name': 'N',
          'brand': 'B',
          'ipName': 'I',
          'shelfAccentArgb': 0xFF112233,
          'figures': const [],
        },
      ],
      'figureStates': const {},
    });

    final decoded = CollectionSnapshotCodec.tryDecode(legacy)!;
    expect(decoded.shelfSeries, hasLength(1));
    expect(decoded.seriesWishlist, isEmpty);
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

  test('Wishlist survives storage round-trip', () async {
    SharedPreferences.setMockInitialValues({});
    const snap = CollectionSnapshot(
      shelfSeries: [
        ShelfSeries(
          id: 's1',
          name: 'Owned Series',
          brand: 'POP MART',
          ipName: 'Molly',
          figures: [
            ShelfFigure(
              id: 'f1',
              seriesId: 's1',
              name: 'Owned Figure',
              rarity: 'Regular',
              isSecret: false,
            ),
            ShelfFigure(
              id: 'f2',
              seriesId: 's1',
              name: 'Saved Figure',
              rarity: 'Regular',
              isSecret: false,
            ),
          ],
          shelfAccent: Color(0xFFE8DEF5),
          catalogTemplateId: 'cat-owned',
        ),
      ],
      figureStates: {
        'f1': TrackedFigure(
          figureId: 'f1',
          state: FigureCollectionState.owned,
          updatedAtMicros: 10,
        ),
        'f2': TrackedFigure(
          figureId: 'f2',
          state: FigureCollectionState.wishlist,
          updatedAtMicros: 20,
        ),
      },
      seriesWishlist: [
        WishlistedCatalogSeries(
          catalogSeriesId: 'cat-saved',
          name: 'Saved Series',
          brand: 'POP MART',
          ipName: 'THE MONSTERS',
          imageKey: 'cat-saved',
          addedAtMicros: 30,
        ),
      ],
    );

    await CollectionSnapshotStorage.save(snap);
    final loaded = await CollectionSnapshotStorage.load();

    expect(loaded, isNotNull);
    expect(loaded!.seriesWishlist.single.catalogSeriesId, 'cat-saved');
    expect(loaded.figureStates['f1']?.state, FigureCollectionState.owned);
    expect(loaded.figureStates['f2']?.state, FigureCollectionState.wishlist);
  });
}
