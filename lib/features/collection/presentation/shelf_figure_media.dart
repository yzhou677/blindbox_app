import 'package:blindbox_app/core/media/device_local_ref.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';

/// Resolves shelf thumbnail strings for **[ShelfSeries]** / **[ShelfFigure]** only.
///
/// Priority for each figure tile:
/// 1. [ShelfFigure.localImageUri] (device path / `file:` URI)
/// 2. [ShelfSeries.customCoverImageUri] (series cover)
/// 3. [ShelfFigure.imageUrl] (catalog-resolved asset path, network URL, etc.)
/// 4. `null` → placeholder
///
/// Catalog clones keep using [ShelfFigure.imageUrl] populated from
/// [CatalogImageResolver] in the seed adapter; they do not use [imageKey] on
/// the shelf — only resolved paths in [imageUrl].
abstract final class ShelfFigureMedia {
  static String? figureDisplayRef(ShelfFigure figure, ShelfSeries series, {bool includeSeriesCoverFallback = true}) {
    final local = figure.localImageUri?.trim();
    if (local != null && local.isNotEmpty) return local;
    if (includeSeriesCoverFallback) {
      final cover = series.customCoverImageUri?.trim();
      if (cover != null && cover.isNotEmpty) return cover;
    }
    final catalog = figure.imageUrl?.trim();
    if (catalog != null && catalog.isNotEmpty) return catalog;
    return null;
  }

  /// Series row art: custom cover first, else first figure ref (excluding redundant cover pass).
  static String? seriesRepresentativeRef(ShelfSeries series) {
    final cover = series.customCoverImageUri?.trim();
    if (cover != null && cover.isNotEmpty) return cover;
    for (final f in series.figures) {
      final r = figureDisplayRef(f, series, includeSeriesCoverFallback: false);
      if (r != null && r.isNotEmpty) return r;
    }
    return null;
  }

  /// True when [ref] should be loaded as a device file (not `assets/`, not http).
  static bool isDeviceLocalRef(String? ref) => DeviceLocalImageRef.looksLikeDevicePath(ref);

  static String normalizeDevicePath(String ref) => DeviceLocalImageRef.normalizeToFilePath(ref);
}
