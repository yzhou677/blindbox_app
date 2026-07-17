import 'package:blindbox_app/features/catalog/presentation/figure_gallery/catalog_figure_gallery_meta.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';

/// Presentation-only labels for the wishlist figure details sheet.
abstract final class WishlistFigureDetailsMetadata {
  static String typeLabel(ShelfFigure figure) =>
      figure.isSecret ? 'Secret Figure' : 'Regular Figure';

  static String? oddsLabel(ShelfFigure figure) {
    final explicitOdds = catalogFigureGalleryNormalizeOdds(figure.rarityLabel);
    if (explicitOdds != null) return explicitOdds;

    final split = catalogFigureGallerySplitRarityOdds(figure.rarity);
    return split.odds ?? catalogFigureGalleryNormalizeOdds(figure.rarity);
  }
}
