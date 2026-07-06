import 'package:blindbox_app/core/layout/feed_rhythm.dart';
import 'package:blindbox_app/core/theme/app_radii.dart';
import 'package:blindbox_app/core/theme/collectible_shelf_shadow.dart';
import 'package:blindbox_app/core/theme/collectible_typography.dart';
import 'package:blindbox_app/features/recommendations/domain/recommendation_item.dart';
import 'package:blindbox_app/features/recommendations/presentation/for_you_copy.dart';
import 'package:blindbox_app/features/catalog/presentation/catalog_image_display.dart';
import 'package:blindbox_app/shared/widgets/catalog_image_from_key.dart';
import 'package:flutter/material.dart';

class ForYouSeriesCard extends StatelessWidget {
  const ForYouSeriesCard({
    super.key,
    required this.item,
    required this.onTap,
  });

  final RecommendationItem item;
  final VoidCallback onTap;

  static const double _imageAspect = 1.05;

  @override
  Widget build(BuildContext context) {
    final series = item.series;
    if (series == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final isDark = theme.brightness == Brightness.dark;
    final accent = scheme.tertiaryContainer;
    final reason = forYouReason(item.reasonType, item.reasonMeta);

    return SizedBox(
      width: FeedRhythm.homeSeriesRailCardWidth,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: AppRadii.shellRadius,
          boxShadow: CollectibleShelfShadow.productShell(context, accent: accent),
        ),
        child: Material(
          color: scheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: AppRadii.shellRadius,
            side: BorderSide(
              color: accent.withValues(alpha: isDark ? 0.16 : 0.3),
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AspectRatio(
                  aspectRatio: _imageAspect,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
                    child: ClipRRect(
                      borderRadius: AppRadii.insetRadius,
                      child: CatalogImageFromKey(
                        imageKey: series.imageKey,
                        name: series.displayName,
                        seedKey: series.id,
                        displayMode: CatalogImageDisplayMode.seriesCoverThumb,
                        compact: true,
                        borderRadius: BorderRadius.zero,
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 2, 16, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        series.displayName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: CollectibleTypography.seriesHeroTitle(
                          textTheme,
                          scheme,
                        ).copyWith(fontSize: 19),
                      ),
                      if (reason.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          reason,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: CollectibleTypography.catalogSeriesRowMeta(
                            textTheme,
                            scheme,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
