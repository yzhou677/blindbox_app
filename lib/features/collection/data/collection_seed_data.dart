import 'package:blindbox_app/features/collection/data/collection_catalog.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';

/// Builds the default in-memory shelf (swap for API + persistence later).
abstract final class CollectionSeedData {
  static CollectionSnapshot initialSnapshot() {
    final shelfSeries = CollectionCatalog.defaultShelfSeries();

    final figureStates = <String, TrackedFigure>{
      'fig-hirono-fox': const TrackedFigure(
        figureId: 'fig-hirono-fox',
        state: FigureCollectionState.owned,
      ),
      'fig-hirono-bird': const TrackedFigure(
        figureId: 'fig-hirono-bird',
        state: FigureCollectionState.wishlist,
      ),
      'fig-skull-milk': const TrackedFigure(
        figureId: 'fig-skull-milk',
        state: FigureCollectionState.owned,
      ),
      'fig-skull-panda': const TrackedFigure(
        figureId: 'fig-skull-panda',
        state: FigureCollectionState.wishlist,
      ),
      'fig-labubu-vinyl': const TrackedFigure(
        figureId: 'fig-labubu-vinyl',
        state: FigureCollectionState.owned,
      ),
      'fig-labubu-heart': const TrackedFigure(
        figureId: 'fig-labubu-heart',
        state: FigureCollectionState.wishlist,
      ),
      'fig-custom-spring-1': const TrackedFigure(
        figureId: 'fig-custom-spring-1',
        state: FigureCollectionState.owned,
      ),
      'fig-custom-spring-2': const TrackedFigure(
        figureId: 'fig-custom-spring-2',
        state: FigureCollectionState.owned,
      ),
      'fig-custom-spring-3': const TrackedFigure(
        figureId: 'fig-custom-spring-3',
        state: FigureCollectionState.wishlist,
      ),
    };

    return CollectionSnapshot(
      shelfSeries: shelfSeries,
      figureStates: figureStates,
    );
  }
}
