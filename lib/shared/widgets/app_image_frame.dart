import 'package:blindbox_app/core/theme/app_image_styles.dart';
import 'package:blindbox_app/core/theme/app_radii.dart';
import 'package:blindbox_app/core/theme/app_spacing.dart';
import 'package:blindbox_app/features/catalog/presentation/catalog_image_display.dart';
import 'package:flutter/material.dart';

/// Premium inset frame for figure thumbnails — never stretches child art.
class AppImageFrame extends StatelessWidget {
  const AppImageFrame({
    super.key,
    required this.child,
    this.extent,
    this.borderRadius,
    this.displayMode,
  });

  final Widget child;
  final double? extent;
  final BorderRadius? borderRadius;

  /// When set, picks default extent for the surface.
  final CatalogImageDisplayMode? displayMode;

  double? _defaultExtent() {
    return switch (displayMode) {
      CatalogImageDisplayMode.figureThumb => AppImageStyles.figureThumbExtent,
      CatalogImageDisplayMode.figureLineupCell =>
        AppImageStyles.figureLineupExtent,
      _ => null,
    };
  }

  BorderRadius _radius() {
    if (borderRadius != null) return borderRadius!;
    return switch (displayMode) {
      CatalogImageDisplayMode.figureLineupCell => AppRadii.figureLineupRadius,
      CatalogImageDisplayMode.figureGallery => AppRadii.figureGalleryRadius,
      CatalogImageDisplayMode.figureThumb || _ => AppRadii.figureThumbRadius,
    };
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final size = extent ?? _defaultExtent();
    final radius = _radius();
    final inner = BorderRadius.circular(
      (radius.topLeft.x - 3).clamp(8.0, 20.0),
    );

    final framed = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        color: AppImageStyles.figureMat(scheme),
        border: AppImageStyles.figureThumbBorder(scheme),
        boxShadow: AppImageStyles.softThumbShadow(scheme),
      ),
      child: Padding(
        padding: AppSpacing.figureThumbInset,
        child: ClipRRect(
          borderRadius: inner,
          child: child,
        ),
      ),
    );

    if (size != null) {
      return SizedBox(width: size, height: size, child: framed);
    }
    return framed;
  }
}
