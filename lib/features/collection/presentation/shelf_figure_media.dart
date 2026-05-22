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
/// Catalog clones prefer [ShelfFigure.imageUrl] from [CatalogImageResolver] at add time.
/// When figure URL is missing, [ShelfFigureThumb] resolves via [ShelfFigure.catalogFigureTemplateId]
/// → `catalog/figures/<imageKey>.<ext>`.
///
/// Series shelf covers: [seriesCoverRef] (user cover only) or [CollectionSeriesThumbnail]
/// via [ShelfSeries.catalogTemplateId] → `catalog/series/<imageKey>.<ext>` — never figure art.
abstract final class ShelfFigureMedia {
  static String? figureDisplayRef(
    ShelfFigure figure,
    ShelfSeries series, {
    bool includeSeriesCoverFallback = true,
  }) {
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

  /// User series cover path/URI only — not figure thumbnails or catalog Storage URLs.
  static String? seriesCoverRef(ShelfSeries series) {
    final cover = series.customCoverImageUri?.trim();
    if (cover != null && cover.isNotEmpty) return cover;
    return null;
  }

  /// True when [ref] should be loaded as a device file (not `assets/`, not http).
  static bool isDeviceLocalRef(String? ref) =>
      DeviceLocalImageRef.looksLikeDevicePath(ref);

  static String normalizeDevicePath(String ref) =>
      DeviceLocalImageRef.normalizeToFilePath(ref);
}
