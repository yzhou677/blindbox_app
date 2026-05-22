import 'package:blindbox_app/core/media/device_local_ref.dart';
import 'package:blindbox_app/features/catalog/presentation/catalog_image_display.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/collection/presentation/shelf_figure_media.dart';
import 'package:blindbox_app/features/collection/widgets/collectible_figure_placeholder.dart';
import 'package:blindbox_app/shared/widgets/catalog_image_from_key.dart';
import 'package:blindbox_app/shared/widgets/collectible_thumb_image.dart';
import 'package:flutter/material.dart';

/// Shelf figure tile — local photo, else [CatalogImageFromKey] from [ShelfFigure.imageKey].
class ShelfFigureThumb extends StatelessWidget {
  const ShelfFigureThumb({
    super.key,
    required this.figure,
    required this.series,
    required this.name,
    required this.seedKey,
    this.isSecret = false,
    this.compact = false,
    this.displayMode = CatalogImageDisplayMode.figureThumb,
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
  });

  final ShelfFigure figure;
  final ShelfSeries series;
  final String name;
  final String seedKey;
  final bool isSecret;
  final bool compact;
  final CatalogImageDisplayMode displayMode;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    final localRef = ShelfFigureMedia.figureDisplayRef(figure, series);
    if (localRef != null &&
        DeviceLocalImageRef.looksLikeDevicePath(localRef)) {
      return CollectibleThumbImage(
        imageRef: localRef,
        name: name,
        seedKey: seedKey,
        isSecret: isSecret,
        compact: compact,
        borderRadius: borderRadius,
        catalogDisplayMode: displayMode,
      );
    }

    final catalogImageKey = ShelfFigureMedia.catalogFigureImageKey(figure);
    if (catalogImageKey != null) {
      return CatalogImageFromKey(
        imageKey: catalogImageKey,
        name: name,
        seedKey: seedKey,
        isSecret: isSecret,
        compact: compact,
        displayMode: displayMode,
        borderRadius: borderRadius,
      );
    }

    return CollectibleFigurePlaceholder(
      name: name,
      seedKey: seedKey,
      isSecret: isSecret,
      compact: compact,
    );
  }
}
