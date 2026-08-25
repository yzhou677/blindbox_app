import 'dart:io';

import 'package:blindbox_app/core/theme/app_radii.dart';
import 'package:blindbox_app/features/catalog/presentation/catalog_aspect_image.dart';
import 'package:blindbox_app/features/catalog/presentation/catalog_image_display.dart';
import 'package:blindbox_app/features/catalog/presentation/figure_gallery/catalog_immersive_feathered_subject.dart';
import 'package:blindbox_app/features/catalog/presentation/figure_gallery/catalog_immersive_figure_stage.dart';
import 'package:blindbox_app/features/collection/widgets/collectible_figure_placeholder.dart';
import 'package:blindbox_app/shared/widgets/app_image_shimmer.dart';
import 'package:blindbox_app/shared/widgets/collectible_thumb_image.dart';
import 'package:flutter/material.dart';

/// Fullscreen gallery stage for local-file figure art.
///
/// Visual composition matches [CatalogResolvedImage] immersive gallery mode.
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

  static const Duration _layerFadeIn = Duration.zero;
  static const Duration _layerFadeOut = Duration.zero;

  @override
  Widget build(BuildContext context) {
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
    final radius = AppRadii.figureGalleryRadius;
    final showBackdrop = useBackdrop && !spec.fillsFrame;
    final slot = CatalogImmersiveFigureStage.innerSlotSize(
      constraints: constraints,
      spec: spec,
    );
    final slotW = slot.width ?? width;
    final slotH = slot.height ?? height;

    ImageProvider foregroundProvider() {
      if (file != null) {
        return CatalogImmersiveImageProviders.file(file!);
      }
      return CatalogImmersiveImageProviders.fromDisplayRef(ref);
    }

    Widget buildBackdrop() {
      if (file != null) {
        return CatalogAspectImage.coverFile(
          file: file!,
          fit: BoxFit.cover,
          fillBounds: true,
          decodeExtent: decode,
        );
      }
      if (CollectibleThumbImage.isAssetPath(ref)) {
        return CatalogAspectImage.presentAsset(
          key: ValueKey<String>('gallery-bg:$ref'),
          asset: ref,
          fit: BoxFit.cover,
          fillBounds: true,
          filterQuality: spec.filterQuality,
          decodeExtent: decode,
        );
      }
      return CatalogAspectImage.presentNetwork(
        key: ValueKey<String>('gallery-bg:$ref'),
        imageUrl: ref,
        cacheKey: ref,
        fit: BoxFit.cover,
        fillBounds: true,
        filterQuality: spec.filterQuality,
        decodeExtent: decode,
        fadeInDuration: _layerFadeIn,
        fadeOutDuration: _layerFadeOut,
        placeholder: (_, _) => AppImageShimmer(borderRadius: radius),
        errorWidget: (_, _, _) => CollectibleFigurePlaceholder(
          name: name,
          seedKey: seedKey,
          isSecret: isSecret,
        ),
      );
    }

    final foregroundSubject = CatalogImmersiveFeatheredSubject(
      key: ValueKey<String>('gallery-fg:$ref:${file?.path}'),
      imageProvider: foregroundProvider(),
      slotWidth: slotW,
      slotHeight: slotH,
      filterQuality: spec.filterQuality,
      decodeExtent: decode,
      placeholder: (context) => AppImageShimmer(borderRadius: radius),
      errorBuilder: (context, error, stackTrace) => CollectibleFigurePlaceholder(
        name: name,
        seedKey: seedKey,
        isSecret: isSecret,
      ),
    );

    if (!showBackdrop) {
      return SizedBox(
        width: width,
        height: height,
        child: ClipRRect(
          borderRadius: radius,
          child: CatalogImmersiveFigureStage.subjectContainLayer(
            constraints: constraints,
            spec: spec,
            child: foregroundSubject,
          ),
        ),
      );
    }

    return SizedBox(
      width: width,
      height: height,
      child: CatalogImmersiveFigureStage(
        constraints: constraints,
        borderRadius: radius,
        spec: spec,
        backdrop: buildBackdrop(),
        foregroundSubject: foregroundSubject,
      ),
    );
  }
}
