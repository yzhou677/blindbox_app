import 'package:blindbox_app/core/layout/feed_rhythm.dart';
import 'package:blindbox_app/core/theme/app_radii.dart';
import 'package:blindbox_app/features/catalog/presentation/catalog_image_display.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/collection/presentation/collection_series_art.dart';
import 'package:blindbox_app/features/collection/presentation/shelf_figure_media.dart';
import 'package:blindbox_app/features/collection/widgets/collectible_figure_placeholder.dart';
import 'package:blindbox_app/shared/widgets/catalog_image_from_key.dart';
import 'package:blindbox_app/shared/widgets/collectible_thumb_image.dart';
import 'package:flutter/material.dart';

/// Compact shelf thumbnail — canonical series cover or placeholder.
class CollectionSeriesThumbnail extends StatelessWidget {
  const CollectionSeriesThumbnail({
    super.key,
    required this.series,
    this.extent,
  });

  final ShelfSeries series;
  final double? extent;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final size = extent ?? FeedRhythm.collectionShelfThumbnailExtent;
    final userCover = ShelfFigureMedia.seriesCoverRef(series);
    final catalogSeriesKey = CollectionSeriesArt.catalogSeriesImageKey(series);
    final name = series.name;
    final seed = series.catalogTemplateId ?? series.id;
    final secret = false;
    final r = AppRadii.insetRadius;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      width: size,
      height: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: r,
          border: Border.all(
            color: series.shelfAccent.withValues(alpha: isDark ? 0.32 : 0.28),
          ),
          color: isDark
              ? scheme.surfaceContainerHigh
              : scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        ),
        child: ClipRRect(
          borderRadius: r,
          child: _seriesThumbContent(
            userCover: userCover,
            catalogSeriesKey: catalogSeriesKey,
            name: name,
            seed: seed,
            secret: secret,
          ),
        ),
      ),
    );
  }
}

Widget _seriesThumbContent({
  required String? userCover,
  required String? catalogSeriesKey,
  required String name,
  required String seed,
  required bool secret,
}) {
  if (userCover != null && userCover.isNotEmpty) {
    return CollectibleThumbImage(
      imageRef: userCover,
      name: name,
      seedKey: seed,
      isSecret: secret,
      fit: BoxFit.cover,
      borderRadius: BorderRadius.zero,
    );
  }

  if (catalogSeriesKey != null && catalogSeriesKey.isNotEmpty) {
    return CatalogImageFromKey(
      imageKey: catalogSeriesKey,
      name: name,
      seedKey: seed,
      isSecret: secret,
      displayMode: CatalogImageDisplayMode.seriesCoverThumb,
      compact: true,
      borderRadius: BorderRadius.zero,
    );
  }

  return CollectibleFigurePlaceholder(
    name: name,
    seedKey: seed,
    isSecret: secret,
    compact: true,
  );
}
