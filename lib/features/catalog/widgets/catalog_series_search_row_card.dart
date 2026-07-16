import 'package:blindbox_app/core/theme/app_radii.dart';
import 'package:blindbox_app/core/theme/collectible_typography.dart';
import 'package:blindbox_app/features/catalog/presentation/catalog_image_display.dart';
import 'package:blindbox_app/features/catalog/presentation/catalog_series_search_rows.dart';
import 'package:blindbox_app/features/collection/presentation/collection_series_shelf_cta_presentation.dart';
import 'package:blindbox_app/features/collection/widgets/collection_series_shelf_cta_trailing.dart';
import 'package:blindbox_app/shared/widgets/catalog_image_from_key.dart';
import 'package:blindbox_app/shared/widgets/collectible_browse_card.dart';
import 'package:flutter/material.dart';

/// Series-centric catalog search result row (shared by Home browse and Add Series).
class CatalogSeriesSearchRowCard extends StatelessWidget {
  const CatalogSeriesSearchRowCard({
    super.key,
    required this.row,
    required this.onOpenPreview,
    required this.shelfCta,
    this.onShelfCtaPressed,
    this.isWishlisted = false,
    this.onWishlistPressed,
  });

  final CatalogSeriesSearchRow row;
  final VoidCallback onOpenPreview;
  final CollectionSeriesShelfCtaPresentation shelfCta;
  final VoidCallback? onShelfCtaPressed;
  final bool isWishlisted;
  final VoidCallback? onWishlistPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final secretTint = scheme.tertiary;
    final onTrailing = shelfCta.enabled
        ? (onShelfCtaPressed ?? onOpenPreview)
        : null;

    return CollectibleBrowseCard(
      onTap: onOpenPreview,
      borderColor: row.hasAnySecret ? secretTint.withValues(alpha: 0.38) : null,
      fillColor: row.hasAnySecret
          ? Color.lerp(scheme.surfaceContainerLow, secretTint, 0.07)
          : null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          CatalogImageSlot(
            displayMode: CatalogImageDisplayMode.seriesCoverThumb,
            borderRadius: AppRadii.insetRadius,
            child: row.coverImageKey.isNotEmpty
                ? CatalogImageFromKey(
                    key: catalogImageWidgetKey(
                      displayMode: CatalogImageDisplayMode.seriesCoverThumb,
                      imageKey: row.coverImageKey,
                      identity: row.seriesId,
                    ),
                    imageKey: row.coverImageKey,
                    name: row.seriesTitle,
                    seedKey: row.seriesId,
                    compact: true,
                    displayMode: CatalogImageDisplayMode.seriesCoverThumb,
                    borderRadius: BorderRadius.zero,
                  )
                : ColoredBox(
                    color: scheme.surfaceContainerHighest.withValues(
                      alpha: 0.5,
                    ),
                    child: Icon(
                      Icons.photo_outlined,
                      color: scheme.onSurfaceVariant.withValues(alpha: 0.45),
                    ),
                  ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row.seriesTitle,
                  style: CollectibleTypography.catalogSeriesRowTitle(
                    textTheme,
                    scheme,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  row.ipLine,
                  style: CollectibleTypography.catalogSeriesRowIp(
                    textTheme,
                    scheme,
                  ),
                ),
                if (row.brand.trim().isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    row.brand.trim(),
                    style: CollectibleTypography.catalogSeriesRowMeta(
                      textTheme,
                      scheme,
                    ),
                  ),
                ],
                const SizedBox(height: 3),
                Text(
                  row.summaryLine,
                  style: CollectibleTypography.catalogSeriesRowMeta(
                    textTheme,
                    scheme,
                  ),
                ),
              ],
            ),
          ),
          if (onWishlistPressed != null && shelfCta.isAddable) ...[
            IconButton(
              tooltip: isWishlisted
                  ? 'Remove series from wishlist'
                  : 'Add series to wishlist',
              onPressed: onWishlistPressed,
              icon: Icon(
                isWishlisted
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                size: 21,
                color: isWishlisted ? scheme.primary : scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 2),
          ],
          CollectionSeriesShelfCtaTrailing(
            presentation: shelfCta,
            onPressed: onTrailing,
          ),
        ],
      ),
    );
  }
}
