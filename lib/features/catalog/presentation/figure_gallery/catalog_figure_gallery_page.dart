import 'dart:io';

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
          final h = constraints.maxHeight * 0.84;

          return Center(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {},
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Theme.of(context).colorScheme.shadow.withValues(
                        alpha: 0.14,
                      ),
                      blurRadius: 32,
                      offset: const Offset(0, 14),
                      spreadRadius: -8,
                    ),
                  ],
                ),
                child: _GalleryArt(
                  item: item,
                  width: w,
                  height: h,
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

    final url = item.imageUrl?.trim();
    if (url != null && url.isNotEmpty) {
      return CatalogGalleryStage(
        width: width,
        height: height,
        imageRef: url,
        name: item.name,
        seedKey: item.id,
        isSecret: item.isSecret,
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
          borderRadius: BorderRadius.circular(24),
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
