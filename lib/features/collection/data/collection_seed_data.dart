import 'package:blindbox_app/features/collection/data/collection_catalog.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';

/// Builds the default in-memory shelf (swap for API + persistence later).
abstract final class CollectionSeedData {
  static CollectionSnapshot initialSnapshot() {
    final shelfSeries = CollectionCatalog.defaultShelfSeries();

    final figureStates = <String, TrackedFigure>{
      'fig-hirono-fox': const TrackedFigure(figureId: 'fig-hirono-fox', owned: true, wishlist: false),
      'fig-hirono-bird': const TrackedFigure(figureId: 'fig-hirono-bird', owned: false, wishlist: true),
      'fig-skull-milk': const TrackedFigure(figureId: 'fig-skull-milk', owned: true, wishlist: false),
      'fig-skull-panda': const TrackedFigure(figureId: 'fig-skull-panda', owned: false, wishlist: true),
      'fig-labubu-vinyl': const TrackedFigure(figureId: 'fig-labubu-vinyl', owned: true, wishlist: false),
      'fig-labubu-heart': const TrackedFigure(figureId: 'fig-labubu-heart', owned: false, wishlist: true),
      'fig-custom-spring-1': const TrackedFigure(figureId: 'fig-custom-spring-1', owned: true, wishlist: false),
      'fig-custom-spring-2': const TrackedFigure(figureId: 'fig-custom-spring-2', owned: true, wishlist: false),
      'fig-custom-spring-3': const TrackedFigure(figureId: 'fig-custom-spring-3', owned: false, wishlist: true),
    };

    return CollectionSnapshot(
      shelfSeries: shelfSeries,
      figureStates: figureStates,
    );
  }
}
