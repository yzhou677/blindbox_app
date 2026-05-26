import 'package:blindbox_app/core/layout/feed_rhythm.dart';
import 'package:blindbox_app/core/theme/app_radii.dart';
import 'package:blindbox_app/features/catalog/presentation/catalog_aspect_image.dart';
import 'package:blindbox_app/features/official_feed/domain/official_feed_sources.dart';
import 'package:blindbox_app/features/official_feed/presentation/official_feed_source_presenter.dart';
import 'package:flutter/material.dart';

/// Small square thumb for compact official update rows.
class OfficialFeedThumbnail extends StatelessWidget {
  const OfficialFeedThumbnail({
    super.key,
    required this.imageUrl,
    this.sourceId,
  });

  final String imageUrl;
  final String? sourceId;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final extent = FeedRhythm.homeOfficialFeedThumbnailExtent;
    final decodeExtent =
        (extent * MediaQuery.devicePixelRatioOf(context) * 1.75).round();

    return ClipRRect(
      borderRadius: AppRadii.figureThumbRadius,
      child: SizedBox(
        width: extent,
        height: extent,
        child: CatalogAspectImage.presentNetwork(
          imageUrl: imageUrl,
          decodeExtent: decodeExtent,
          placeholder: (_, _) => ColoredBox(
            color: scheme.surfaceContainerHighest.withValues(
              alpha: isDark ? 0.45 : 0.55,
            ),
          ),
          errorWidget: (_, _, _) => _imageFallback(context),
        ),
      ),
    );
  }

  Widget _imageFallback(BuildContext context) {
    if (sourceId == OfficialFeedSources.popmartUs) {
      return const Center(child: OfficialFeedSourceMark(sourceId: OfficialFeedSources.popmartUs));
    }
    final scheme = Theme.of(context).colorScheme;
    return ColoredBox(
      color: scheme.surfaceContainerHigh,
      child: Icon(
        Icons.image_outlined,
        size: 22,
        color: scheme.onSurfaceVariant.withValues(alpha: 0.35),
      ),
    );
  }
}
