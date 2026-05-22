import 'package:flutter/material.dart';

/// UI-only presets for catalog art (bundled assets + Firebase Storage URLs).
///
/// Does not change [CatalogImageResolver] paths, [imageKey], or Storage layout.
enum CatalogImageDisplayMode {
  /// Square shelf / search row series cover (~52–64 logical px).
  seriesCoverThumb,

  /// Large series cover — Discover cards, release detail hero.
  seriesCoverHero,

  /// Shelf figure tile, add-sheet figure preview, compact thumbs.
  figureThumb,

  /// Home release lineup strip cell (~78 logical px).
  figureLineupCell,

  /// Collection figure capsule card art window.
  figureCapsule,

  /// Market browse when wired to catalog series art (not eBay listing photos).
  marketCatalogThumb,
}

/// Normalized render settings for one catalog image surface.
@immutable
class CatalogImageDisplaySpec {
  const CatalogImageDisplaySpec({
    required this.fit,
    required this.alignment,
    required this.filterQuality,
    required this.fadeInDuration,
    required this.fadeOutDuration,
    required this.contentPadding,
    required this.matOpacity,
    this.memCacheLogicalExtent,
  });

  final BoxFit fit;
  final Alignment alignment;
  final FilterQuality filterQuality;
  final Duration fadeInDuration;
  final Duration fadeOutDuration;

  /// Inset so transparent PNG/WEBP figures and box art breathe inside the frame.
  final EdgeInsets contentPadding;

  /// Soft mat behind transparent catalog art ([surface] alpha).
  final double matOpacity;

  /// Typical longest side in logical pixels — drives decode/cache cap (not layout).
  final double? memCacheLogicalExtent;

  static CatalogImageDisplaySpec forMode(CatalogImageDisplayMode mode) {
    return switch (mode) {
      CatalogImageDisplayMode.seriesCoverThumb => const CatalogImageDisplaySpec(
          fit: BoxFit.contain,
          alignment: Alignment.center,
          filterQuality: FilterQuality.high,
          fadeInDuration: Duration(milliseconds: 220),
          fadeOutDuration: Duration(milliseconds: 120),
          contentPadding: EdgeInsets.all(6),
          matOpacity: 0.58,
          memCacheLogicalExtent: 72,
        ),
      CatalogImageDisplayMode.seriesCoverHero => const CatalogImageDisplaySpec(
          fit: BoxFit.contain,
          alignment: Alignment.center,
          filterQuality: FilterQuality.high,
          fadeInDuration: Duration(milliseconds: 340),
          fadeOutDuration: Duration(milliseconds: 140),
          contentPadding: EdgeInsets.all(14),
          matOpacity: 0.72,
          memCacheLogicalExtent: 280,
        ),
      CatalogImageDisplayMode.figureThumb => const CatalogImageDisplaySpec(
          fit: BoxFit.contain,
          alignment: Alignment.center,
          filterQuality: FilterQuality.medium,
          fadeInDuration: Duration(milliseconds: 220),
          fadeOutDuration: Duration(milliseconds: 120),
          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          matOpacity: 0.65,
          memCacheLogicalExtent: 96,
        ),
      CatalogImageDisplayMode.figureLineupCell => const CatalogImageDisplaySpec(
          fit: BoxFit.contain,
          alignment: Alignment.center,
          filterQuality: FilterQuality.medium,
          fadeInDuration: Duration(milliseconds: 180),
          fadeOutDuration: Duration(milliseconds: 100),
          contentPadding: EdgeInsets.all(5),
          matOpacity: 0.62,
          memCacheLogicalExtent: 88,
        ),
      CatalogImageDisplayMode.figureCapsule => const CatalogImageDisplaySpec(
          fit: BoxFit.contain,
          alignment: Alignment.center,
          filterQuality: FilterQuality.medium,
          fadeInDuration: Duration(milliseconds: 260),
          fadeOutDuration: Duration(milliseconds: 120),
          contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          matOpacity: 0.68,
          memCacheLogicalExtent: 140,
        ),
      CatalogImageDisplayMode.marketCatalogThumb => const CatalogImageDisplaySpec(
          fit: BoxFit.contain,
          alignment: Alignment.center,
          filterQuality: FilterQuality.high,
          fadeInDuration: Duration(milliseconds: 220),
          fadeOutDuration: Duration(milliseconds: 120),
          contentPadding: EdgeInsets.all(6),
          matOpacity: 0.58,
          memCacheLogicalExtent: 96,
        ),
    };
  }

  /// Decode/cache cap from layout size — avoids decoding huge Storage sources at full res.
  int? memCacheWidthFor(BoxConstraints constraints, double devicePixelRatio) {
    return _memCacheDim(constraints.maxWidth, devicePixelRatio);
  }

  int? memCacheHeightFor(BoxConstraints constraints, double devicePixelRatio) {
    return _memCacheDim(constraints.maxHeight, devicePixelRatio);
  }

  int? _memCacheDim(double logical, double dpr) {
    if (!logical.isFinite || logical <= 0) {
      final hint = memCacheLogicalExtent;
      if (hint == null) return null;
      return (hint * dpr * 2).round().clamp(64, 768);
    }
    return (logical * dpr * 2).round().clamp(64, 768);
  }
}
