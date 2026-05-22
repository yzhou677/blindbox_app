import 'package:blindbox_app/core/media/device_local_ref.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';

/// Device-local media refs for shelf rows — catalog art uses [ShelfFigure.imageKey] in UI.
///
/// [figureDisplayRef] returns only on-device paths (figure photo or optional series cover).
/// Catalog / Storage art is rendered by [CatalogImageFromKey] via [catalogFigureImageKey].
///
/// [ShelfFigure.imageUrl] may exist in persistence as an optional cache; UI must not read it.
abstract final class ShelfFigureMedia {
  /// Canonical catalog figure key for [CatalogImageFromKey], when present.
  static String? catalogFigureImageKey(ShelfFigure figure) {
    final key = figure.imageKey?.trim();
    if (key != null && key.isNotEmpty) return key;
    final templateId = figure.catalogFigureTemplateId?.trim();
    if (templateId != null && templateId.isNotEmpty) return templateId;
    return null;
  }

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
