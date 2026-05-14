import 'package:blindbox_app/core/layout/feed_rhythm.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/collection/presentation/collection_series_art.dart';
import 'package:blindbox_app/features/collection/widgets/collectible_figure_placeholder.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Compact shelf thumbnail — representative figure art or [CollectibleFigurePlaceholder].
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
    final url = CollectionSeriesArt.representativeImageUrl(series);
    final anchor = CollectionSeriesArt.anchorFigure(series);
    final name = anchor?.name ?? series.name;
    final seed = anchor?.id ?? series.id;
    final secret = anchor?.isSecret ?? false;
    final r = BorderRadius.circular(14);

    return SizedBox(
      width: size,
      height: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: r,
          border: Border.all(
            color: series.shelfAccent.withValues(alpha: 0.28),
          ),
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
        ),
        child: ClipRRect(
          borderRadius: r,
          child: url != null
              ? CachedNetworkImage(
                  imageUrl: url,
                  fit: BoxFit.cover,
                  fadeInDuration: const Duration(milliseconds: 200),
                  errorWidget: (context, url, error) => CollectibleFigurePlaceholder(
                    name: name,
                    seedKey: seed,
                    isSecret: secret,
                    compact: true,
                  ),
                )
              : CollectibleFigurePlaceholder(
                  name: name,
                  seedKey: seed,
                  isSecret: secret,
                  compact: true,
                ),
        ),
      ),
    );
  }
}
