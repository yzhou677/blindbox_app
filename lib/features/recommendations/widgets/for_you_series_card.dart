import 'package:blindbox_app/core/theme/app_radii.dart';
import 'package:blindbox_app/core/theme/collectible_elevation.dart';
import 'package:blindbox_app/core/theme/collectible_typography.dart';
import 'package:blindbox_app/features/catalog/presentation/catalog_image_display.dart';
import 'package:blindbox_app/features/recommendations/domain/recommendation_item.dart';
import 'package:blindbox_app/features/recommendations/presentation/for_you_copy.dart';
import 'package:blindbox_app/shared/widgets/catalog_image_from_key.dart';
import 'package:flutter/material.dart';

/// Compact image-first card — same footprint as Market Chasers mini cards.
const double kForYouRailCardWidth = 168;

class ForYouSeriesCard extends StatelessWidget {
  const ForYouSeriesCard({
    super.key,
    required this.item,
    required this.onTap,
  });

  final RecommendationItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final series = item.series;
    if (series == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final isDark = theme.brightness == Brightness.dark;
    final reasons = forYouReasonLines(item);
    final thumbExtent = kForYouRailCardWidth - 24;

    return SizedBox(
      width: kForYouRailCardWidth,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: AppRadii.cardRadius,
          boxShadow: CollectibleElevation.softCard(context),
        ),
        child: Material(
          color: scheme.surface,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: AppRadii.cardRadius,
            side: BorderSide(
              color: scheme.outlineVariant.withValues(alpha: isDark ? 0.32 : 0.38),
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: Center(
                      child: SizedBox(
                        width: thumbExtent,
                        height: thumbExtent,
                        child: ClipRRect(
                          borderRadius: AppRadii.matRadius,
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
                  ),
                  const SizedBox(height: 10),
                  Text(
                    series.displayName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: CollectibleTypography.catalogSeriesRowTitle(
                      textTheme,
                      scheme,
                    ),
                  ),
                  if (reasons.primary != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      reasons.primary!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.labelSmall!.copyWith(
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.06,
                        color: scheme.onSurfaceVariant.withValues(alpha: 0.84),
                      ),
                    ),
                  ],
                  if (reasons.secondary != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      reasons.secondary!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.labelSmall!.copyWith(
                        fontWeight: FontWeight.w400,
                        letterSpacing: 0.04,
                        color: scheme.onSurfaceVariant.withValues(alpha: 0.42),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
