import 'dart:ui';

import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('emptyTest is empty shelf', () {
    expect(CollectionSnapshot.emptyTest().isEmptyShelf, isTrue);
  });

  test('shelf series alone is not empty', () {
    final snap = CollectionSnapshot(
      shelfSeries: [
        ShelfSeries(
          id: 's1',
          name: 'S',
          brand: 'B',
          ipName: 'I',
          figures: const [],
          shelfAccent: const Color(0xFFE8F5E9),
        ),
      ],
      figureStates: const {},
    );
    expect(snap.isEmptyShelf, isFalse);
  });

  test('seriesWishlist alone is not empty', () {
    final snap = CollectionSnapshot(
      shelfSeries: const [],
      figureStates: const {},
      seriesWishlist: [
        WishlistedCatalogSeries(
          catalogSeriesId: 'w1',
          name: 'Wish',
          brand: 'B',
          ipName: 'I',
          imageKey: 'k',
          addedAtMicros: 1,
        ),
      ],
    );
    expect(snap.isEmptyShelf, isFalse);
    expect(snap.totalWishlistItems, 1);
  });

  test('owned or wishlist figureStates alone is not empty', () {
    final owned = CollectionSnapshot(
      shelfSeries: const [],
      figureStates: {
        'f1': const TrackedFigure(
          figureId: 'f1',
          state: FigureCollectionState.owned,
          ownedQuantity: 1,
        ),
      },
    );
    expect(owned.isEmptyShelf, isFalse);

    final wish = CollectionSnapshot(
      shelfSeries: const [],
      figureStates: {
        'f2': const TrackedFigure(
          figureId: 'f2',
          state: FigureCollectionState.wishlist,
        ),
      },
    );
    expect(wish.isEmptyShelf, isFalse);
    expect(wish.totalWishlistItems, 1);
  });

  test('none figureStates do not count as content', () {
    final snap = CollectionSnapshot(
      shelfSeries: const [],
      figureStates: {
        'f1': const TrackedFigure(
          figureId: 'f1',
          state: FigureCollectionState.none,
        ),
      },
    );
    expect(snap.isEmptyShelf, isTrue);
  });
}
