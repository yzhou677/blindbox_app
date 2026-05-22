import 'dart:io';

import 'package:blindbox_app/core/layout/feed_rhythm.dart';
import 'package:blindbox_app/core/presentation/collectible_immersion.dart';
import 'package:blindbox_app/core/theme/app_radii.dart';
import 'package:blindbox_app/core/theme/app_spacing.dart';
import 'package:blindbox_app/features/catalog/presentation/catalog_image_display.dart';
import 'package:blindbox_app/features/catalog/presentation/figure_gallery/catalog_figure_gallery_item.dart';
import 'package:blindbox_app/features/catalog/presentation/figure_gallery/catalog_gallery_stage.dart';
import 'package:blindbox_app/features/collection/widgets/collectible_figure_placeholder.dart';
import 'package:blindbox_app/shared/widgets/catalog_image_from_key.dart';
import 'package:flutter/material.dart';

/// Single fullscreen gallery page — immersive stage with progressive loading.
class CatalogFigureGalleryPage extends StatelessWidget {
  const CatalogFigureGalleryPage({
    super.key,
    required this.item,
  });

  final CatalogFigureGalleryItem item;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: AppSpacing.galleryPage,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final h = constraints.maxHeight * FeedRhythm.galleryStageMaxHeightFactor;

          return Center(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {},
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: AppRadii.figureGalleryRadius,
                  boxShadow: [
                    BoxShadow(
                      color: Theme.of(context).colorScheme.shadow.withValues(
                        alpha: 0.12,
                      ),
                      blurRadius: 36,
                      offset: const Offset(0, 16),
                      spreadRadius: -10,
                    ),
                  ],
                ),
                child: Stack(
                  fit: StackFit.passthrough,
                  children: [
                    _GalleryArt(
                      item: item,
                      width: w,
                      height: h,
                    ),
                    Positioned.fill(
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: AppRadii.figureGalleryRadius,
                            gradient: RadialGradient(
                              center: Alignment.center,
                              radius: 1.05,
                              colors: [
                                Colors.transparent,
                                CollectibleImmersion.galleryStageVignette(
                                  Theme.of(context).colorScheme,
                                ),
                              ],
                              stops: const [0.55, 1],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _GalleryArt extends StatelessWidget {
  const _GalleryArt({
    required this.item,
    required this.width,
    required this.height,
  });

  final CatalogFigureGalleryItem item;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final local = item.localImageUri?.trim();
    if (local != null && local.isNotEmpty) {
      final path = local.startsWith('file:')
          ? Uri.parse(local).toFilePath()
          : local;
      return CatalogGalleryStage(
        width: width,
        height: height,
        imageRef: path,
        name: item.name,
        seedKey: item.id,
        isSecret: item.isSecret,
        file: File(path),
      );
    }

    if (item.hasCatalogKey) {
      return SizedBox(
        width: width,
        height: height,
        child: CatalogImageFromKey(
          key: catalogImageWidgetKey(
            displayMode: CatalogImageDisplayMode.figureGallery,
            imageKey: item.catalogImageKey!,
            identity: item.id,
          ),
          imageKey: item.catalogImageKey!,
          name: item.name,
          seedKey: item.id,
          isSecret: item.isSecret,
          displayMode: CatalogImageDisplayMode.figureGallery,
          borderRadius: AppRadii.figureGalleryRadius,
          width: width,
          height: height,
        ),
      );
    }

    return SizedBox(
      width: width * 0.72,
      height: height * 0.5,
      child: CollectibleFigurePlaceholder(
        name: item.name,
        seedKey: item.id,
        isSecret: item.isSecret,
      ),
    );
  }
}
