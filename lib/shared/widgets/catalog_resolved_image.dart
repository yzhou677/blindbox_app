import 'package:blindbox_app/features/catalog/presentation/catalog_aspect_image.dart';
import 'package:blindbox_app/features/catalog/presentation/catalog_image_display.dart';
import 'package:blindbox_app/features/collection/widgets/collectible_figure_placeholder.dart';
import 'package:blindbox_app/shared/widgets/collectible_thumb_image.dart';
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

        final framed = ClipRRect(
          borderRadius: radius,
          child: ColoredBox(
            color: mat,
            child: spec.fillsFrame
                ? _coverFrame(constraints: constraints, image: image)
                : _subjectContainFrame(constraints: constraints, image: image),
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
  }) {
    CatalogAspectImage.assertAspectPreservingFit(spec.fit);
    final decodeExtent = spec.memCacheDecodeExtent(constraints, dpr);
    final expansive = spec.fillsFrame;

    if (CollectibleThumbImage.isAssetPath(ref)) {
      return CatalogAspectImage.presentAsset(
        asset: ref,
        key: ValueKey<String>('catalog-asset:$ref'),
        fit: spec.fit,
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
      fit: spec.fit,
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
    return ColoredBox(
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
      child: const Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
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
