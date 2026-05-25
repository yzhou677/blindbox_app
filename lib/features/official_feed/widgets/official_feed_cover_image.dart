import 'package:blindbox_app/core/layout/feed_rhythm.dart';
import 'package:blindbox_app/features/catalog/presentation/catalog_aspect_image.dart';
import 'package:flutter/material.dart';

/// Network cover for official feed cards — fixed aspect, decode cap, calm fade.
class OfficialFeedCoverImage extends StatelessWidget {
  const OfficialFeedCoverImage({super.key, required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final decodeExtent = (FeedRhythm.homeOfficialFeedCardWidth * dpr * 1.5)
        .round();

    return AspectRatio(
      aspectRatio: FeedRhythm.homeOfficialFeedImageAspect,
      child: CatalogAspectImage.presentNetwork(
        imageUrl: imageUrl,
        decodeExtent: decodeExtent,
        placeholder: (_, _) => _ImageMat(scheme: scheme, isDark: isDark),
        errorWidget: (_, _, _) => _ImageMat(
          scheme: scheme,
          isDark: isDark,
          showIcon: true,
        ),
      ),
    );
  }
}

class _ImageMat extends StatelessWidget {
  const _ImageMat({
    required this.scheme,
    required this.isDark,
    this.showIcon = false,
  });

  final ColorScheme scheme;
  final bool isDark;
  final bool showIcon;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: scheme.surfaceContainerHighest.withValues(
        alpha: isDark ? 0.5 : 0.62,
      ),
      child: showIcon
          ? Center(
              child: Icon(
                Icons.image_not_supported_outlined,
                size: 28,
                color: scheme.onSurfaceVariant.withValues(alpha: 0.4),
              ),
            )
          : null,
    );
  }
}
