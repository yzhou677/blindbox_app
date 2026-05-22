import 'package:blindbox_app/core/theme/app_image_styles.dart';
import 'package:blindbox_app/core/theme/app_radii.dart';
import 'package:blindbox_app/shared/widgets/app_image_frame.dart';
import 'package:flutter/material.dart';

/// Adaptive presentation intent — UI only, not Storage/Firestore.
enum CatalogImageMode {
  /// Discover/search/recommendation series art — immersive cover crop.
  editorial,

  /// Figure rows, shelf miniatures — preserve silhouette (contain + light zoom).
  figure,

  /// Cutout PNG/WebP figures — contain, gentle zoom, minimal crop.
  transparentFigure,

  /// Series detail / release hero — large cover, balanced crop.
  hero,

  /// Compact square series thumb (search, shelf series tile).
  thumbnail,
}

/// How art is placed inside its mat — UI only.
enum CatalogImageFraming {
  /// Cover fill with clipped overflow (editorial / hero / thumbnail).
  coverFill,

  /// Subject-first: [BoxFit.contain] + optional zoom; avoids chopping heads.
  subjectContain,
}

/// Surface-specific preset — maps to a [CatalogImageMode] via [CatalogImageDisplaySpec.forMode].
enum CatalogImageDisplayMode {
  seriesCoverThumb,
  seriesCoverHero,
  figureThumb,
  figureLineupCell,
  figureCapsule,
  figureGallery,
  marketCatalogThumb,
}

/// Normalized render settings for one catalog image surface.
@immutable
class CatalogImageDisplaySpec {
  const CatalogImageDisplaySpec({
    required this.presentationMode,
    required this.framing,
    required this.fit,
    required this.alignment,
    required this.filterQuality,
    required this.fadeInDuration,
    required this.fadeOutDuration,
    required this.contentPadding,
    required this.matOpacity,
    this.subjectZoom = 1.0,
    this.memCacheLogicalExtent,
    this.memCacheDevicePixelScale = 1.25,
  });

  final CatalogImageMode presentationMode;
  final CatalogImageFraming framing;
  final BoxFit fit;
  final Alignment alignment;
  final FilterQuality filterQuality;
  final Duration fadeInDuration;
  final Duration fadeOutDuration;
  final EdgeInsets contentPadding;
  final double matOpacity;

  /// Uniform scale inside [CatalogImageFraming.subjectContain] frames only.
  final double subjectZoom;
  final double? memCacheLogicalExtent;
  final double memCacheDevicePixelScale;

  bool get fillsFrame => framing == CatalogImageFraming.coverFill;

  /// @deprecated Use [subjectZoom].
  double get figureZoom => subjectZoom;

  static CatalogImageMode presentationModeFor(CatalogImageDisplayMode surface) {
    return switch (surface) {
      CatalogImageDisplayMode.seriesCoverThumb => CatalogImageMode.thumbnail,
      CatalogImageDisplayMode.seriesCoverHero => CatalogImageMode.hero,
      CatalogImageDisplayMode.marketCatalogThumb => CatalogImageMode.editorial,
      CatalogImageDisplayMode.figureThumb ||
      CatalogImageDisplayMode.figureLineupCell ||
      CatalogImageDisplayMode.figureCapsule ||
      CatalogImageDisplayMode.figureGallery => CatalogImageMode.figure,
    };
  }

  /// Resolves adaptive spec for a UI surface, optionally refining from [imageRef].
  static CatalogImageDisplaySpec forMode(
    CatalogImageDisplayMode surface, {
    String? imageRef,
  }) {
    var mode = presentationModeFor(surface);
    if (mode == CatalogImageMode.figure && looksLikeFigureAsset(imageRef)) {
      mode = CatalogImageMode.transparentFigure;
    } else if (surface == CatalogImageDisplayMode.figureThumb &&
        mode == CatalogImageMode.figure &&
        looksLikePhotoFigureAsset(imageRef)) {
      return _figureThumbPhotoSpec();
    }
    return forPresentationMode(mode, surface: surface);
  }

  /// Opaque promo / photo figure art — gentle cover, not harsh square crop.
  static bool looksLikePhotoFigureAsset(String? ref) {
    final r = ref?.trim().toLowerCase();
    if (r == null || r.isEmpty) return false;
    if (looksLikeFigureAsset(r)) return false;
    return r.endsWith('.jpg') ||
        r.endsWith('.jpeg') ||
        r.contains('promo') ||
        r.contains('photo');
  }

  static CatalogImageDisplaySpec _figureThumbPhotoSpec() {
    return const CatalogImageDisplaySpec(
      presentationMode: CatalogImageMode.figure,
      framing: CatalogImageFraming.coverFill,
      fit: BoxFit.cover,
      alignment: Alignment(0, -0.08),
      filterQuality: FilterQuality.high,
      fadeInDuration: AppImageStyles.imageFadeIn,
      fadeOutDuration: AppImageStyles.imageFadeOut,
      contentPadding: EdgeInsets.zero,
      matOpacity: 0.38,
      memCacheLogicalExtent: 220,
      memCacheDevicePixelScale: 1.85,
    );
  }

  static bool looksLikeFigureAsset(String? ref) {
    final r = ref?.trim().toLowerCase();
    if (r == null || r.isEmpty) return false;
    return r.contains('assets/catalog/figures/') ||
        r.contains('catalog/figures/');
  }

  static CatalogImageDisplaySpec forPresentationMode(
    CatalogImageMode mode, {
    CatalogImageDisplayMode? surface,
  }) {
    return switch (mode) {
      CatalogImageMode.editorial => const CatalogImageDisplaySpec(
        presentationMode: CatalogImageMode.editorial,
        framing: CatalogImageFraming.coverFill,
        fit: BoxFit.cover,
        alignment: Alignment(0, -0.12),
        filterQuality: FilterQuality.high,
        fadeInDuration: Duration(milliseconds: 220),
        fadeOutDuration: Duration(milliseconds: 120),
        contentPadding: EdgeInsets.zero,
        matOpacity: 0.34,
        memCacheLogicalExtent: 144,
        memCacheDevicePixelScale: 1.75,
      ),
      CatalogImageMode.thumbnail => const CatalogImageDisplaySpec(
        presentationMode: CatalogImageMode.thumbnail,
        framing: CatalogImageFraming.coverFill,
        fit: BoxFit.cover,
        alignment: Alignment(0, -0.1),
        filterQuality: FilterQuality.high,
        fadeInDuration: Duration(milliseconds: 220),
        fadeOutDuration: Duration(milliseconds: 120),
        contentPadding: EdgeInsets.zero,
        matOpacity: 0.36,
        memCacheLogicalExtent: 136,
        memCacheDevicePixelScale: 1.75,
      ),
      CatalogImageMode.hero => const CatalogImageDisplaySpec(
        presentationMode: CatalogImageMode.hero,
        framing: CatalogImageFraming.coverFill,
        fit: BoxFit.cover,
        alignment: Alignment(0, -0.08),
        filterQuality: FilterQuality.high,
        fadeInDuration: Duration(milliseconds: 340),
        fadeOutDuration: Duration(milliseconds: 140),
        contentPadding: EdgeInsets.zero,
        matOpacity: 0.3,
        memCacheLogicalExtent: 400,
        memCacheDevicePixelScale: 1.5,
      ),
      CatalogImageMode.figure => CatalogImageDisplaySpec(
        presentationMode: CatalogImageMode.figure,
        framing: CatalogImageFraming.subjectContain,
        fit: BoxFit.contain,
        alignment: _figureAlignmentFor(surface),
        filterQuality: FilterQuality.high,
        fadeInDuration: const Duration(milliseconds: 220),
        fadeOutDuration: const Duration(milliseconds: 120),
        contentPadding: _figurePaddingFor(surface),
        matOpacity: 0.5,
        subjectZoom: _figureZoomFor(surface),
        memCacheLogicalExtent: _figureDecodeHintFor(surface),
        memCacheDevicePixelScale: 2.0,
      ),
      CatalogImageMode.transparentFigure => CatalogImageDisplaySpec(
        presentationMode: CatalogImageMode.transparentFigure,
        framing: CatalogImageFraming.subjectContain,
        fit: BoxFit.contain,
        alignment: Alignment.center,
        filterQuality: FilterQuality.high,
        fadeInDuration: const Duration(milliseconds: 220),
        fadeOutDuration: const Duration(milliseconds: 120),
        contentPadding: _figurePaddingFor(surface, transparent: true),
        matOpacity: 0.46,
        subjectZoom: _figureZoomFor(surface, transparent: true),
        memCacheLogicalExtent: _figureDecodeHintFor(surface),
        memCacheDevicePixelScale: 2.0,
      ),
    };
  }

  static Alignment _figureAlignmentFor(CatalogImageDisplayMode? surface) {
    return switch (surface) {
      CatalogImageDisplayMode.figureGallery => Alignment.center,
      CatalogImageDisplayMode.figureLineupCell => const Alignment(0, -0.04),
      _ => const Alignment(0, -0.06),
    };
  }

  static EdgeInsets _figurePaddingFor(
    CatalogImageDisplayMode? surface, {
    bool transparent = false,
  }) {
    if (transparent) {
      return switch (surface) {
        CatalogImageDisplayMode.figureGallery => const EdgeInsets.all(8),
        CatalogImageDisplayMode.figureCapsule => const EdgeInsets.symmetric(
          horizontal: 4,
          vertical: 3,
        ),
        CatalogImageDisplayMode.figureLineupCell => const EdgeInsets.all(2),
        _ => const EdgeInsets.all(3),
      };
    }
    return switch (surface) {
      CatalogImageDisplayMode.figureGallery => const EdgeInsets.all(6),
      CatalogImageDisplayMode.figureCapsule => const EdgeInsets.symmetric(
        horizontal: 3,
        vertical: 2,
      ),
      CatalogImageDisplayMode.figureLineupCell => const EdgeInsets.all(1),
      _ => const EdgeInsets.all(2),
    };
  }

  static double _figureZoomFor(
    CatalogImageDisplayMode? surface, {
    bool transparent = false,
  }) {
    if (transparent) {
      return switch (surface) {
        CatalogImageDisplayMode.figureGallery => 1.04,
        CatalogImageDisplayMode.figureLineupCell => 1.08,
        CatalogImageDisplayMode.figureCapsule => 1.07,
        _ => 1.08,
      };
    }
    return switch (surface) {
      CatalogImageDisplayMode.figureGallery => 1.04,
      CatalogImageDisplayMode.figureLineupCell => 1.08,
      CatalogImageDisplayMode.figureCapsule => 1.06,
      _ => 1.07,
    };
  }

  static double? _figureDecodeHintFor(CatalogImageDisplayMode? surface) {
    return switch (surface) {
      CatalogImageDisplayMode.figureGallery => 720.0,
      CatalogImageDisplayMode.figureCapsule => 280.0,
      CatalogImageDisplayMode.figureLineupCell => 240.0,
      _ => 200.0,
    };
  }

  static BorderRadius borderRadiusFor(CatalogImageDisplayMode mode) {
    return switch (mode) {
      CatalogImageDisplayMode.seriesCoverHero => BorderRadius.circular(14),
      CatalogImageDisplayMode.seriesCoverThumb ||
      CatalogImageDisplayMode.marketCatalogThumb => BorderRadius.circular(12),
      CatalogImageDisplayMode.figureCapsule => AppRadii.insetRadius,
      CatalogImageDisplayMode.figureGallery => AppRadii.figureGalleryRadius,
      CatalogImageDisplayMode.figureLineupCell => AppRadii.figureLineupRadius,
      CatalogImageDisplayMode.figureThumb => AppRadii.figureThumbRadius,
    };
  }

  static double? aspectRatioFor(CatalogImageDisplayMode mode) {
    return switch (mode) {
      CatalogImageDisplayMode.seriesCoverHero => 1.0,
      CatalogImageDisplayMode.seriesCoverThumb ||
      CatalogImageDisplayMode.marketCatalogThumb => 1.0,
      _ => null,
    };
  }

  static double? layoutExtentFor(CatalogImageDisplayMode mode) {
    return switch (mode) {
      CatalogImageDisplayMode.seriesCoverThumb => 68,
      CatalogImageDisplayMode.figureThumb => AppImageStyles.figureThumbExtent,
      CatalogImageDisplayMode.figureLineupCell =>
        AppImageStyles.figureLineupExtent,
      CatalogImageDisplayMode.marketCatalogThumb => 72,
      _ => null,
    };
  }

  int? memCacheDecodeExtent(
    BoxConstraints constraints,
    double devicePixelRatio,
  ) {
    final scale = memCacheDevicePixelScale.clamp(1.0, 2.0);
    final zoomFactor = framing == CatalogImageFraming.subjectContain
        ? subjectZoom.clamp(1.0, 1.15)
        : 1.0;
    var logical = 0.0;

    if (constraints.maxWidth.isFinite && constraints.maxHeight.isFinite) {
      logical = constraints.maxWidth > constraints.maxHeight
          ? constraints.maxWidth
          : constraints.maxHeight;
    } else if (constraints.maxWidth.isFinite) {
      logical = constraints.maxWidth;
    } else if (constraints.maxHeight.isFinite) {
      logical = constraints.maxHeight;
    }

    if (logical <= 0) {
      final hint = memCacheLogicalExtent;
      if (hint == null) return null;
      return (hint * devicePixelRatio * scale * zoomFactor).round().clamp(
        96,
        1024,
      );
    }

    final maxExtent = presentationMode == CatalogImageMode.figure &&
            memCacheLogicalExtent != null &&
            memCacheLogicalExtent! >= 600
        ? 1536
        : 1024;
    return (logical * devicePixelRatio * scale * zoomFactor)
        .round()
        .clamp(96, maxExtent);
  }

  @Deprecated(
    'Use memCacheDecodeExtent — height must stay null to avoid stretch.',
  )
  int? memCacheWidthFor(BoxConstraints constraints, double devicePixelRatio) =>
      memCacheDecodeExtent(constraints, devicePixelRatio);

  @Deprecated('Always null — dual-axis decode distorts aspect ratio.')
  int? memCacheHeightFor(BoxConstraints constraints, double devicePixelRatio) =>
      null;
}

/// Fixed-ratio slot for catalog art — keeps search/discover cards visually even.
class CatalogImageSlot extends StatelessWidget {
  const CatalogImageSlot({
    super.key,
    required this.displayMode,
    required this.child,
    this.width,
    this.height,
    this.borderRadius,
  });

  final CatalogImageDisplayMode displayMode;
  final Widget child;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final extent = CatalogImageDisplaySpec.layoutExtentFor(displayMode);
    final w = width ?? extent;
    final h = height ?? extent;
    final radius =
        borderRadius ?? CatalogImageDisplaySpec.borderRadiusFor(displayMode);
    final ar = CatalogImageDisplaySpec.aspectRatioFor(displayMode);

    Widget body = child;
    if (w != null && h != null) {
      body = SizedBox(width: w, height: h, child: child);
    } else if (ar != null) {
      body = AspectRatio(aspectRatio: ar, child: child);
    }

    if (_usesPremiumFigureFrame(displayMode)) {
      return AppImageFrame(
        extent: w,
        displayMode: displayMode,
        borderRadius: radius,
        child: body,
      );
    }

    return ClipRRect(borderRadius: radius, child: body);
  }

  static bool _usesPremiumFigureFrame(CatalogImageDisplayMode mode) {
    return switch (mode) {
      CatalogImageDisplayMode.figureThumb ||
      CatalogImageDisplayMode.figureLineupCell => true,
      _ => false,
    };
  }
}
