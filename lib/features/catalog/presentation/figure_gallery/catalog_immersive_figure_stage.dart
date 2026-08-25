import 'dart:ui' show ImageFilter;

import 'package:blindbox_app/features/catalog/presentation/catalog_image_display.dart';
import 'package:blindbox_app/features/catalog/presentation/figure_gallery/catalog_immersive_feathered_subject.dart';
import 'package:flutter/material.dart';

/// Visual composition for fullscreen gallery figure art — backdrop + foreground.
///
/// Does not resolve image references; callers supply pre-built [backdrop] and
/// [CatalogImmersiveFeatheredSubject] for the foreground.
class CatalogImmersiveFigureStage extends StatelessWidget {
  const CatalogImmersiveFigureStage({
    super.key,
    required this.constraints,
    required this.borderRadius,
    required this.spec,
    required this.backdrop,
    required this.foregroundSubject,
  });

  final BoxConstraints constraints;
  final BorderRadius borderRadius;
  final CatalogImageDisplaySpec spec;
  final Widget backdrop;
  final CatalogImmersiveFeatheredSubject foregroundSubject;

  /// Backdrop cover enlargement (fills stage without gaps after blur).
  static const double backdropScale = 1.12;

  /// Keeps blurred art subordinate to the sharp foreground.
  static const double backdropOpacity = 0.52;

  static const double blurSigma = 28;

  static const double scrimAlpha = 0.38;

  static const double edgeFeatherFraction = 0.11;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return ClipRRect(
      borderRadius: borderRadius,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: RepaintBoundary(
              child: Opacity(
                opacity: backdropOpacity,
                child: ImageFiltered(
                  imageFilter: ImageFilter.blur(
                    sigmaX: blurSigma,
                    sigmaY: blurSigma,
                  ),
                  child: Transform.scale(
                    scale: backdropScale,
                    child: ClipRect(child: backdrop),
                  ),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: ColoredBox(
              color: scheme.scrim.withValues(alpha: scrimAlpha),
            ),
          ),
          subjectContainLayer(
            constraints: constraints,
            spec: spec,
            child: foregroundSubject,
          ),
        ],
      ),
    );
  }

  /// Subject-first foreground framing — same sizing as [CatalogResolvedImage].
  static Widget subjectContainLayer({
    required BoxConstraints constraints,
    required CatalogImageDisplaySpec spec,
    required Widget child,
  }) {
    final pad = spec.contentPadding;
    final zoom = spec.subjectZoom.clamp(1.0, 1.2);

    return Padding(
      padding: pad,
      child: Align(
        alignment: spec.alignment,
        child: Transform.scale(scale: zoom, child: child),
      ),
    );
  }

  /// Inner contain slot size (padding subtracted, before [subjectZoom]).
  static ({double? width, double? height}) innerSlotSize({
    required BoxConstraints constraints,
    required CatalogImageDisplaySpec spec,
  }) {
    final pad = spec.contentPadding;
    final innerW = constraints.maxWidth.isFinite
        ? (constraints.maxWidth - pad.horizontal).clamp(0.0, double.infinity)
        : null;
    final innerH = constraints.maxHeight.isFinite
        ? (constraints.maxHeight - pad.vertical).clamp(0.0, double.infinity)
        : null;
    return (width: innerW, height: innerH);
  }
}
