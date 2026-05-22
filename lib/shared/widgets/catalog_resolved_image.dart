import 'package:blindbox_app/features/catalog/presentation/catalog_image_display.dart';
import 'package:blindbox_app/features/collection/widgets/collectible_figure_placeholder.dart';
import 'package:blindbox_app/shared/widgets/collectible_thumb_image.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Renders a resolved catalog asset path or Storage URL with shared presentation rules.
class CatalogResolvedImage extends StatelessWidget {
  const CatalogResolvedImage({
    super.key,
    required this.imageRef,
    required this.spec,
    required this.name,
    required this.seedKey,
    this.isSecret = false,
    this.compact = false,
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
    this.width,
    this.height,
  });

  final String imageRef;
  final CatalogImageDisplaySpec spec;
  final String name;
  final String seedKey;
  final bool isSecret;
  final bool compact;
  final BorderRadius borderRadius;
  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final ref = imageRef.trim();
    if (ref.isEmpty) {
      return _placeholder();
    }

    Widget content = LayoutBuilder(
      builder: (context, constraints) {
        final scheme = Theme.of(context).colorScheme;
        final dpr = MediaQuery.devicePixelRatioOf(context);
        final mat = scheme.surface.withValues(alpha: spec.matOpacity);

        final Widget image;
        if (CollectibleThumbImage.isAssetPath(ref)) {
          image = Image.asset(
            ref,
            fit: spec.fit,
            alignment: spec.alignment,
            filterQuality: spec.filterQuality,
            width: constraints.maxWidth.isFinite ? constraints.maxWidth : null,
            height: constraints.maxHeight.isFinite ? constraints.maxHeight : null,
            errorBuilder: (context, error, stackTrace) {
              debugPrint('CatalogResolvedImage: asset "$ref" failed: $error');
              return _placeholder();
            },
          );
        } else {
          image = CachedNetworkImage(
            imageUrl: ref,
            fit: spec.fit,
            alignment: spec.alignment,
            filterQuality: spec.filterQuality,
            memCacheWidth: spec.memCacheWidthFor(constraints, dpr),
            memCacheHeight: spec.memCacheHeightFor(constraints, dpr),
            fadeInDuration: spec.fadeInDuration,
            fadeOutDuration: spec.fadeOutDuration,
            placeholder: (context, url) => _loadingMat(scheme),
            errorWidget: (context, url, error) => _placeholder(),
          );
        }

        return ClipRRect(
          borderRadius: borderRadius,
          child: ColoredBox(
            color: mat,
            child: Padding(
              padding: spec.contentPadding,
              child: Center(child: image),
            ),
          ),
        );
      },
    );

    if (width != null || height != null) {
      content = SizedBox(width: width, height: height, child: content);
    }
    return content;
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

  Widget _placeholder() {
    return ClipRRect(
      borderRadius: borderRadius,
      child: CollectibleFigurePlaceholder(
        name: name,
        seedKey: seedKey,
        isSecret: isSecret,
        compact: compact,
      ),
    );
  }
}
