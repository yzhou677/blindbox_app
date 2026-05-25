import 'dart:io';
import 'dart:ui' show ImageFilter;

import 'package:blindbox_app/core/theme/app_image_styles.dart';
import 'package:blindbox_app/core/theme/app_radii.dart';
import 'package:blindbox_app/features/catalog/presentation/catalog_aspect_image.dart';
import 'package:blindbox_app/features/catalog/presentation/catalog_image_display.dart';
import 'package:blindbox_app/features/collection/widgets/collectible_figure_placeholder.dart';
import 'package:blindbox_app/shared/widgets/app_image_shimmer.dart';
import 'package:blindbox_app/shared/widgets/collectible_thumb_image.dart';
import 'package:flutter/material.dart';

/// Fullscreen gallery “stage” — blurred cover backdrop + sharp contain foreground.
///
/// Unifies mixed-aspect promo art without re-exporting database assets.
class CatalogGalleryStage extends StatelessWidget {
  const CatalogGalleryStage({
    super.key,
    required this.width,
    required this.height,
    required this.imageRef,
    required this.name,
    required this.seedKey,
    this.isSecret = false,
    this.file,
    this.useBackdrop = true,
  });

  final double width;
  final double height;
  final String imageRef;
  final String name;
  final String seedKey;
  final bool isSecret;
  final File? file;
  final bool useBackdrop;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ref = imageRef.trim();
    if (file == null && ref.isEmpty) {
      return SizedBox(
        width: width,
        height: height,
        child: CollectibleFigurePlaceholder(
          name: name,
          seedKey: seedKey,
          isSecret: isSecret,
        ),
      );
    }

    final spec = CatalogImageDisplaySpec.forMode(
      CatalogImageDisplayMode.figureGallery,
      imageRef: ref,
    );
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final constraints = BoxConstraints(maxWidth: width, maxHeight: height);
    final decode = spec.memCacheDecodeExtent(constraints, dpr);

    Widget buildLayer({
      required BoxFit fit,
      required bool fillBounds,
      Key? key,
    }) {
      if (file != null) {
        final layer = CatalogAspectImage.coverFile(
          file: file!,
          fit: fit,
          fillBounds: fillBounds,
        );
        return key != null ? KeyedSubtree(key: key, child: layer) : layer;
      }
      if (CollectibleThumbImage.isAssetPath(ref)) {
        return CatalogAspectImage.presentAsset(
          key: key,
          asset: ref,
          fit: fit,
          fillBounds: fillBounds,
          filterQuality: spec.filterQuality,
        );
      }
      return CatalogAspectImage.presentNetwork(
        key: key,
        imageUrl: ref,
        cacheKey: ref,
        fit: fit,
        fillBounds: fillBounds,
        filterQuality: spec.filterQuality,
        decodeExtent: decode,
        fadeInDuration: spec.fadeInDuration,
        fadeOutDuration: spec.fadeOutDuration,
        placeholder: (_, _) => AppImageShimmer(
          borderRadius: AppRadii.figureGalleryRadius,
        ),
        errorWidget: (_, _, _) => CollectibleFigurePlaceholder(
          name: name,
          seedKey: seedKey,
          isSecret: isSecret,
        ),
      );
    }

    final showBackdrop = useBackdrop && !spec.fillsFrame;

    return SizedBox(
      width: width,
      height: height,
      child: ClipRRect(
        borderRadius: AppRadii.figureGalleryRadius,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (showBackdrop) ...[
              Positioned.fill(
                child: Opacity(
                  opacity: 0.52,
                  child: ImageFiltered(
                    imageFilter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                    child: Transform.scale(
                      scale: 1.12,
                      child: buildLayer(
                        key: ValueKey<String>('gallery-bg:$ref'),
                        fit: BoxFit.cover,
                        fillBounds: true,
                      ),
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: ColoredBox(
                  color: scheme.scrim.withValues(alpha: 0.42),
                ),
              ),
            ] else
              ColoredBox(color: AppImageStyles.figureMat(scheme)),
            _ForegroundContain(
              spec: spec,
              child: buildLayer(
                key: ValueKey<String>('gallery-fg:$ref'),
                fit: BoxFit.contain,
                fillBounds: false,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ForegroundContain extends StatelessWidget {
  const _ForegroundContain({required this.spec, required this.child});

  final CatalogImageDisplaySpec spec;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final pad = spec.contentPadding;
    final zoom = spec.subjectZoom.clamp(1.0, 1.15);

    return Padding(
      padding: pad,
      child: Align(
        alignment: spec.alignment,
        child: Transform.scale(scale: zoom, child: child),
      ),
    );
  }
}
