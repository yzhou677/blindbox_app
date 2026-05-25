import 'package:blindbox_app/core/layout/feed_rhythm.dart';
import 'package:blindbox_app/core/theme/app_radii.dart';
import 'package:blindbox_app/features/catalog/presentation/catalog_aspect_image.dart';
import 'package:flutter/material.dart';

/// Small square thumb for compact official update rows.
class OfficialFeedThumbnail extends StatelessWidget {
  const OfficialFeedThumbnail({super.key, required this.imageUrl});

  final String imageUrl;

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
          errorWidget: (_, _, _) => ColoredBox(
            color: scheme.surfaceContainerHigh,
            child: Icon(
              Icons.image_outlined,
              size: 22,
              color: scheme.onSurfaceVariant.withValues(alpha: 0.35),
            ),
          ),
        ),
      ),
    );
  }
}
