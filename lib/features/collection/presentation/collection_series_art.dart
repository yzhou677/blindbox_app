import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/collection/presentation/shelf_figure_media.dart';

/// Centralized shelf media selection for [ShelfSeries] rows.
abstract final class CollectionSeriesArt {
  /// Representative art for a shelf series (local cover → figures → catalog URLs).
  static String? representativeImageUrl(ShelfSeries series) =>
      ShelfFigureMedia.seriesRepresentativeRef(series);

  /// Figure used for initials / placeholder seed (first row).
  static ShelfFigure? anchorFigure(ShelfSeries series) {
    if (series.figures.isEmpty) return null;
    return series.figures.first;
  }

  /// Add-sheet previews for [CatalogSeries] rows (same heuristics as shelf art).
  static String? representativeImageUrlCatalog(CatalogSeries series) {
    for (final f in series.figures) {
      final u = f.imageUrl?.trim();
      if (u != null && u.isNotEmpty) return u;
    }
    return null;
  }

  static CatalogFigure? anchorFigureCatalog(CatalogSeries series) {
    if (series.figures.isEmpty) return null;
    return series.figures.first;
  }
}
