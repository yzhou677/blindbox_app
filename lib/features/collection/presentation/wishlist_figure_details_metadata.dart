import 'package:blindbox_app/features/collection/domain/collection_domain.dart';

/// Presentation-only labels for the wishlist figure details sheet.
abstract final class WishlistFigureDetailsMetadata {
  static String typeLabel(ShelfFigure figure) =>
      figure.isSecret ? 'Secret Figure' : 'Regular Figure';
}
