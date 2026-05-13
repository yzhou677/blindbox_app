import 'package:blindbox_app/features/collection/domain/collection_domain.dart';

/// Centralized shelf media selection for [SeriesDefinition] rows.
abstract final class CollectionSeriesArt {
  /// First catalog figure image URL on the series, if any.
  static String? representativeImageUrl(SeriesDefinition series) {
    for (final f in series.figures) {
      final u = f.imageUrl?.trim();
      if (u != null && u.isNotEmpty) return u;
    }
    return null;
  }

  /// Figure used for initials / placeholder seed (first row).
  static FigureDefinition? anchorFigure(SeriesDefinition series) {
    if (series.figures.isEmpty) return null;
    return series.figures.first;
  }
}
