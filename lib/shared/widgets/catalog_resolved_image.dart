import 'package:blindbox_app/features/catalog/presentation/catalog_aspect_image.dart';
import 'package:blindbox_app/features/catalog/presentation/catalog_image_display.dart';
import 'package:blindbox_app/features/collection/widgets/collectible_figure_placeholder.dart';
import 'package:blindbox_app/shared/widgets/app_image_shimmer.dart';
import 'package:blindbox_app/shared/widgets/collectible_thumb_image.dart';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

/// Renders a resolved catalog asset path or Storage URL with adaptive presentation rules.
class CatalogResolvedImage extends StatelessWidget {
  const CatalogResolvedImage({
    super.key,
    required this.imageRef,
    required this.spec,
    required this.name,
    required this.seedKey,
    this.isSecret = false,
    this.compact = false,
    this.borderRadius,
    this.width,
    this.height,
    this.immersiveGalleryStage = false,
  });

  final String imageRef;
  final CatalogImageDisplaySpec spec;
  final String name;
  final String seedKey;
  final bool isSecret;
  final bool compact;
  final BorderRadius? borderRadius;
  final double? width;
  final double? height;

  /// Blurred cover backdrop + contain foreground (fullscreen gallery).
  final bool immersiveGalleryStage;

  @override
  Widget build(BuildContext context) {
    final ref = imageRef.trim();
    if (ref.isEmpty) {
      return _placeholder(borderRadius ?? BorderRadius.zero);
    }

    final radius = borderRadius ?? BorderRadius.zero;

    Widget content = LayoutBuilder(
      builder: (context, constraints) {
        final scheme = Theme.of(context).colorScheme;
        final dpr = MediaQuery.devicePixelRatioOf(context);
        final mat = _matColor(scheme);

        final image = _buildImage(
          ref: ref,
          constraints: constraints,
          dpr: dpr,
          placeholder: () => _loadingMat(scheme),
          onError: () => _placeholder(radius),
        );

        final framed = immersiveGalleryStage && !spec.fillsFrame
            ? _immersiveGalleryFrame(
                scheme: scheme,
                radius: radius,
                constraints: constraints,
                dpr: dpr,
                ref: ref,
                foreground: image,
                placeholder: () => _loadingMat(scheme),
                onError: () => _placeholder(radius),
              )
            : ClipRRect(
                borderRadius: radius,
                child: ColoredBox(
                  color: mat,
                  child: spec.fillsFrame
                      ? _coverFrame(constraints: constraints, image: image)
                      : _subjectContainFrame(
                          constraints: constraints,
                          image: image,
                        ),
                ),
              );

        return framed;
      },
    );

    if (width != null || height != null) {
      content = SizedBox(width: width, height: height, child: content);
    }
    return content;
  }

  Widget _coverFrame({
    required BoxConstraints constraints,
    required Widget image,
  }) {
    final w = constraints.maxWidth.isFinite ? constraints.maxWidth : null;
    final h = constraints.maxHeight.isFinite ? constraints.maxHeight : null;

    if (w != null && h != null) {
      return SizedBox(
        width: w,
        height: h,
        child: ClipRect(child: image),
      );
    }
    return ClipRect(child: image);
  }

  Widget _subjectContainFrame({
    required BoxConstraints constraints,
    required Widget image,
  }) {
    final pad = spec.contentPadding;
    final innerW = constraints.maxWidth.isFinite
        ? (constraints.maxWidth - pad.horizontal).clamp(0.0, double.infinity)
        : null;
    final innerH = constraints.maxHeight.isFinite
        ? (constraints.maxHeight - pad.vertical).clamp(0.0, double.infinity)
        : null;
    final zoom = spec.subjectZoom.clamp(1.0, 1.2);

    return Padding(
      padding: pad,
      child: ClipRect(
        child: Align(
          alignment: spec.alignment,
          child: Transform.scale(
            scale: zoom,
            child: SizedBox(width: innerW, height: innerH, child: image),
          ),
        ),
      ),
    );
  }

  Widget _immersiveGalleryFrame({
    required ColorScheme scheme,
    required BorderRadius radius,
    required BoxConstraints constraints,
    required double dpr,
    required String ref,
    required Widget foreground,
    required Widget Function() placeholder,
    required Widget Function() onError,
  }) {
    final backdrop = _buildImage(
      ref: ref,
      constraints: constraints,
      dpr: dpr,
      fit: BoxFit.cover,
      fillBounds: true,
      placeholder: placeholder,
      onError: onError,
    );

    return ClipRRect(
      borderRadius: radius,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: Opacity(
              opacity: 0.58,
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 26, sigmaY: 26),
                child: Transform.scale(
                  scale: 1.12,
                  child: ClipRect(child: backdrop),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: ColoredBox(color: scheme.scrim.withValues(alpha: 0.42)),
          ),
          _subjectContainFrame(constraints: constraints, image: foreground),
        ],
      ),
    );
  }

  Color _matColor(ColorScheme scheme) {
    return Color.alphaBlend(
      scheme.surface.withValues(alpha: spec.matOpacity),
      scheme.surfaceContainerHighest.withValues(alpha: 0.12),
    );
  }

  Widget _buildImage({
    required String ref,
    required BoxConstraints constraints,
    required double dpr,
    required Widget Function() placeholder,
    required Widget Function() onError,
    BoxFit? fit,
    bool? fillBounds,
  }) {
    final resolvedFit = fit ?? spec.fit;
    CatalogAspectImage.assertAspectPreservingFit(resolvedFit);
    final decodeExtent = spec.memCacheDecodeExtent(constraints, dpr);
    final expansive = fillBounds ?? spec.fillsFrame;

    if (CollectibleThumbImage.isAssetPath(ref)) {
      return CatalogAspectImage.presentAsset(
        asset: ref,
        key: ValueKey<String>('catalog-asset:$ref'),
        fit: resolvedFit,
        alignment: spec.alignment,
        filterQuality: spec.filterQuality,
        fillBounds: expansive,
        errorBuilder: (context, error, stackTrace) {
          debugPrint('CatalogResolvedImage: asset "$ref" failed: $error');
          return onError();
        },
      );
    }

    return CatalogAspectImage.presentNetwork(
      key: ValueKey<String>('catalog-cached:$ref'),
      imageUrl: ref,
      cacheKey: ref,
      fit: resolvedFit,
      alignment: spec.alignment,
      filterQuality: spec.filterQuality,
      decodeExtent: decodeExtent,
      fillBounds: expansive,
      fadeInDuration: spec.fadeInDuration,
      fadeOutDuration: spec.fadeOutDuration,
      placeholder: (context, url) => placeholder(),
      errorWidget: (context, url, error) => onError(),
    );
  }

  Widget _loadingMat(ColorScheme scheme) {
    return AppImageShimmer(
      borderRadius: borderRadius ?? BorderRadius.zero,
    );
  }

  Widget _placeholder(BorderRadius radius) {
    return ClipRRect(
      borderRadius: radius,
      child: CollectibleFigurePlaceholder(
        name: name,
        seedKey: seedKey,
        isSecret: isSecret,
        compact: compact,
      ),
    );
  }
}
