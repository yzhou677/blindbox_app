import 'package:blindbox_app/core/theme/collectible_typography.dart';
import 'package:blindbox_app/features/catalog/presentation/catalog_image_display.dart';
import 'package:blindbox_app/features/catalog/presentation/catalog_series_search_rows.dart';
import 'package:blindbox_app/shared/widgets/catalog_image_from_key.dart';
import 'package:flutter/material.dart';

/// Series-centric catalog search result row (shared by Home browse and Add Series).
class CatalogSeriesSearchRowCard extends StatelessWidget {
  const CatalogSeriesSearchRowCard({
    super.key,
    required this.row,
    required this.onOpenPreview,
    this.trailingLabel = 'View',
    this.onTrailingAction,
  });

  final CatalogSeriesSearchRow row;
  final VoidCallback onOpenPreview;
  final String trailingLabel;
  final VoidCallback? onTrailingAction;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final onTrailing = onTrailingAction ?? onOpenPreview;

    return Material(
      color: scheme.surfaceContainerLow,
      elevation: 0,
      shadowColor: scheme.shadow.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onOpenPreview,
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: 0.35),
            ),
            color: scheme.surfaceContainerLow,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                CatalogImageSlot(
                  displayMode: CatalogImageDisplayMode.seriesCoverThumb,
                  borderRadius: BorderRadius.circular(14),
                  child: row.coverImageKey.isNotEmpty
                      ? CatalogImageFromKey(
                          key: catalogImageWidgetKey(
                            displayMode:
                                CatalogImageDisplayMode.seriesCoverThumb,
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
                            color: scheme.onSurfaceVariant.withValues(
                              alpha: 0.45,
                            ),
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
                Material(
                  color: scheme.primary.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    onTap: onTrailing,
                    borderRadius: BorderRadius.circular(14),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            trailingLabel,
                            style: textTheme.labelLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: scheme.primary,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.chevron_right_rounded,
                            size: 20,
                            color: scheme.primary,
                          ),
                        ],
                      ),
                    ),
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
