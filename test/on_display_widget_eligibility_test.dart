import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/collection/widget/on_display_widget_sync.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  ShelfSeries shelfSeries(String id) => ShelfSeries(
    id: id,
    name: 'Series $id',
    brand: 'Brand',
    ipName: 'IP',
    figures: const [],
    shelfAccent: Colors.purple,
  );

  test('shelf series with zero owned figures is eligible', () {
    final snapshot = CollectionSnapshot(
      shelfSeries: [shelfSeries('series-1')],
      figureStates: const {},
    );

    expect(eligibleOnDisplaySeries(snapshot).map((s) => s.id), ['series-1']);
  });

  test('wishlist-only series is not eligible', () {
    const wishlisted = WishlistedCatalogSeries(
      catalogSeriesId: 'wish-1',
      name: 'Wishlist Series',
      brand: 'Brand',
      ipName: 'IP',
      imageKey: 'wish-1',
      addedAtMicros: 1,
    );
    const snapshot = CollectionSnapshot(
      shelfSeries: [],
      figureStates: {},
      seriesWishlist: [wishlisted],
    );

    expect(eligibleOnDisplaySeries(snapshot), isEmpty);
  });

  test('candidate list is empty only when Shelf has no series', () {
    final withShelf = CollectionSnapshot(
      shelfSeries: [shelfSeries('series-1')],
      figureStates: const {},
      seriesWishlist: const [],
    );

    expect(eligibleOnDisplaySeries(CollectionSnapshot.emptyTest()), isEmpty);
    expect(eligibleOnDisplaySeries(withShelf), isNotEmpty);
  });
}
