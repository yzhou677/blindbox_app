import 'package:blindbox_app/features/collection/domain/collection_domain.dart';

/// Centralized shelf media selection for [ShelfSeries] rows.
abstract final class CollectionSeriesArt {
  /// First catalog figure image URL on the series, if any.
  static String? representativeImageUrl(ShelfSeries series) {
    for (final f in series.figures) {
      final u = f.imageUrl?.trim();
      if (u != null && u.isNotEmpty) return u;
    }
    return null;
  }

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
