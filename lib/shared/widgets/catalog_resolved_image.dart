import 'dart:io';

import 'package:blindbox_app/core/media/device_local_ref.dart';
import 'package:blindbox_app/features/catalog/presentation/catalog_aspect_image.dart';
import 'package:blindbox_app/features/catalog/presentation/catalog_image_display.dart';
import 'package:blindbox_app/features/catalog/presentation/figure_gallery/catalog_immersive_feathered_subject.dart';
import 'package:blindbox_app/features/catalog/presentation/figure_gallery/catalog_immersive_figure_stage.dart';
import 'package:blindbox_app/features/collection/widgets/collectible_figure_placeholder.dart';
import 'package:blindbox_app/shared/widgets/app_image_shimmer.dart';
import 'package:blindbox_app/shared/widgets/collectible_thumb_image.dart';
import 'package:flutter/foundation.dart';
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

  static const Duration _immersiveLayerFadeIn = Duration.zero;
  static const Duration _immersiveLayerFadeOut = Duration.zero;

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
        final immersive = immersiveGalleryStage && !spec.fillsFrame;

        final framed = immersive
            ? _buildImmersiveStage(
                ref: ref,
                constraints: constraints,
                dpr: dpr,
                scheme: scheme,
                radius: radius,
              )
            : ClipRRect(
                borderRadius: radius,
                child: ColoredBox(
                  color: mat,
                  child: spec.fillsFrame
                      ? _coverFrame(
                          constraints: constraints,
                          image: _buildImage(
                            ref: ref,
                            constraints: constraints,
                            dpr: dpr,
                            placeholder: () => _loadingMat(scheme),
                            onError: () => _placeholder(radius),
                          ),
                        )
                      : _subjectContainFrame(
                          constraints: constraints,
                          image: _buildImage(
                            ref: ref,
                            constraints: constraints,
                            dpr: dpr,
                            placeholder: () => _loadingMat(scheme),
                            onError: () => _placeholder(radius),
                          ),
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
    return ClipRect(
      child: CatalogImmersiveFigureStage.subjectContainLayer(
        constraints: constraints,
        spec: spec,
        child: image,
      ),
    );
  }

  Widget _buildImmersiveStage({
    required String ref,
    required BoxConstraints constraints,
    required double dpr,
    required ColorScheme scheme,
    required BorderRadius radius,
  }) {
    final slot = CatalogImmersiveFigureStage.innerSlotSize(
      constraints: constraints,
      spec: spec,
    );
    final slotW = slot.width ?? constraints.maxWidth;
    final slotH = slot.height ?? constraints.maxHeight;
    final decodeExtent = spec.memCacheDecodeExtent(constraints, dpr);

    return CatalogImmersiveFigureStage(
      constraints: constraints,
      borderRadius: radius,
      spec: spec,
      backdrop: _buildImage(
        ref: ref,
        constraints: constraints,
        dpr: dpr,
        fit: BoxFit.cover,
        fillBounds: true,
        placeholder: () => _loadingMat(scheme),
        onError: () => _placeholder(radius),
        fadeInDuration: _immersiveLayerFadeIn,
        fadeOutDuration: _immersiveLayerFadeOut,
      ),
      foregroundSubject: CatalogImmersiveFeatheredSubject(
        imageProvider: CatalogImmersiveImageProviders.fromDisplayRef(ref),
        slotWidth: slotW,
        slotHeight: slotH,
        filterQuality: spec.filterQuality,
        decodeExtent: decodeExtent,
        placeholder: (context) => _loadingMat(scheme),
        errorBuilder: (context, error, stackTrace) => _placeholder(radius),
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
    Duration? fadeInDuration,
    Duration? fadeOutDuration,
  }) {
    final resolvedFit = fit ?? spec.fit;
    CatalogAspectImage.assertAspectPreservingFit(resolvedFit);
    final decodeExtent = spec.memCacheDecodeExtent(constraints, dpr);
    final expansive = fillBounds ?? spec.fillsFrame;
    final fadeIn = fadeInDuration ?? spec.fadeInDuration;
    final fadeOut = fadeOutDuration ?? spec.fadeOutDuration;

    if (CollectibleThumbImage.isAssetPath(ref)) {
      return CatalogAspectImage.presentAsset(
        asset: ref,
        key: ValueKey<String>('catalog-asset:$ref'),
        fit: resolvedFit,
        alignment: spec.alignment,
        filterQuality: spec.filterQuality,
        fillBounds: expansive,
        decodeExtent: decodeExtent,
        errorBuilder: (context, error, stackTrace) {
          debugPrint('CatalogResolvedImage: asset "$ref" failed: $error');
          return onError();
        },
      );
    }

    if (!kIsWeb && DeviceLocalImageRef.looksLikeDevicePath(ref)) {
      final path = DeviceLocalImageRef.normalizeToFilePath(ref);
      return CatalogAspectImage.coverFile(
        file: File(path),
        fit: resolvedFit,
        alignment: spec.alignment,
        filterQuality: spec.filterQuality,
        fillBounds: expansive,
        decodeExtent: decodeExtent,
        errorBuilder: (context, error, stackTrace) {
          debugPrint('CatalogResolvedImage: disk cache "$ref" failed: $error');
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
      fadeInDuration: fadeIn,
      fadeOutDuration: fadeOut,
      placeholder: (context, url) => placeholder(),
      errorWidget: (context, url, error) => onError(),
    );
  }

  Widget _loadingMat(ColorScheme scheme) {
    return AppImageShimmer(borderRadius: borderRadius ?? BorderRadius.zero);
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
