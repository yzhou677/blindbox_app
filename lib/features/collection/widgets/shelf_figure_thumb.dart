import 'package:blindbox_app/features/catalog/presentation/catalog_image_display.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/collection/presentation/shelf_figure_media.dart';
import 'package:blindbox_app/features/collection/widgets/collectible_figure_placeholder.dart';
import 'package:blindbox_app/shared/widgets/catalog_image_from_key.dart';
import 'package:blindbox_app/shared/widgets/collectible_thumb_image.dart';
import 'package:flutter/material.dart';

/// Shelf figure tile art: local / persisted URL first, else catalog figure [imageKey].
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
    final ref = ShelfFigureMedia.figureDisplayRef(figure, series);
    if (ref != null && ref.isNotEmpty) {
      return CollectibleThumbImage(
        imageRef: ref,
        name: name,
        seedKey: seedKey,
        isSecret: isSecret,
        compact: compact,
        borderRadius: borderRadius,
        catalogDisplayMode: CatalogImageDisplayMode.figureThumb,
      );
    }

    final catalogImageKey = figure.imageKey?.trim();
    if (catalogImageKey != null && catalogImageKey.isNotEmpty) {
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

    final catalogFigureId = figure.catalogFigureTemplateId?.trim();
    if (catalogFigureId != null &&
        catalogFigureId.isNotEmpty &&
        !series.isDropImport) {
      return CatalogImageFromKey(
        imageKey: catalogFigureId,
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
