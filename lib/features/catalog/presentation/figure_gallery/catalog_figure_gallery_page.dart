import 'dart:io';

import 'package:blindbox_app/core/theme/app_radii.dart';
import 'package:blindbox_app/core/theme/app_spacing.dart';
import 'package:blindbox_app/features/catalog/presentation/catalog_aspect_image.dart';
import 'package:blindbox_app/features/catalog/presentation/catalog_image_display.dart';
import 'package:blindbox_app/features/catalog/presentation/figure_gallery/catalog_figure_gallery_item.dart';
import 'package:blindbox_app/features/collection/widgets/collectible_figure_placeholder.dart';
import 'package:blindbox_app/shared/widgets/catalog_image_from_key.dart';
import 'package:blindbox_app/shared/widgets/collectible_thumb_image.dart';
import 'package:flutter/material.dart';

/// Single fullscreen gallery page — art loads progressively after the route opens.
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
          return Center(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: AppRadii.figureGalleryRadius,
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(context).colorScheme.shadow.withValues(
                      alpha: 0.12,
                    ),
                    blurRadius: 28,
                    offset: const Offset(0, 12),
                    spreadRadius: -6,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: AppRadii.figureGalleryRadius,
                child: _GalleryArt(
                  item: item,
                  maxWidth: constraints.maxWidth,
                  maxHeight: constraints.maxHeight * 0.84,
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
    required this.maxWidth,
    required this.maxHeight,
  });

  final CatalogFigureGalleryItem item;
  final double maxWidth;
  final double maxHeight;

  @override
  Widget build(BuildContext context) {
    final local = item.localImageUri?.trim();
    if (local != null && local.isNotEmpty) {
      final path = local.startsWith('file:')
          ? Uri.parse(local).toFilePath()
          : local;
      final file = File(path);
      return SizedBox(
        width: maxWidth,
        height: maxHeight,
        child: CatalogAspectImage.coverFile(
          file: file,
          fit: BoxFit.contain,
          fillBounds: false,
        ),
      );
    }

    if (item.hasCatalogKey) {
      return SizedBox(
        width: maxWidth,
        height: maxHeight,
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
          borderRadius: BorderRadius.zero,
        ),
      );
    }

    final url = item.imageUrl?.trim();
    if (url != null && url.isNotEmpty) {
      return SizedBox(
        width: maxWidth,
        height: maxHeight,
        child: CollectibleThumbImage(
          imageRef: url,
          name: item.name,
          seedKey: item.id,
          isSecret: item.isSecret,
          borderRadius: BorderRadius.zero,
          catalogDisplayMode: CatalogImageDisplayMode.figureGallery,
        ),
      );
    }

    return SizedBox(
      width: maxWidth * 0.72,
      height: maxHeight * 0.5,
      child: CollectibleFigurePlaceholder(
        name: item.name,
        seedKey: item.id,
        isSecret: item.isSecret,
      ),
    );
  }
}
