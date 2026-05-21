import 'package:blindbox_app/features/collection/domain/collection_domain.dart';

/// Shelf series cover keys and placeholder anchors.
abstract final class CollectionSeriesArt {
  /// Catalog series [imageKey] stem when this row was cloned from seed/Firestore.
  static String? catalogSeriesImageKey(ShelfSeries series) {
    if (series.isCustomLocal || series.isDropImport) return null;
    final key = series.imageKey?.trim();
    if (key != null && key.isNotEmpty) return key;
    final id = series.catalogTemplateId?.trim();
    if (id == null || id.isEmpty) return null;
    return id;
  }

  /// Figure used for initials / placeholder seed (first row).
  static ShelfFigure? anchorFigure(ShelfSeries series) {
    if (series.figures.isEmpty) return null;
    return series.figures.first;
  }
}
