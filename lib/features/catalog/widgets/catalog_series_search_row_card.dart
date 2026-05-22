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
    final secretTint = scheme.tertiary;
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
              color: row.hasAnySecret
                  ? secretTint.withValues(alpha: 0.38)
                  : scheme.outlineVariant.withValues(alpha: 0.35),
            ),
            color: row.hasAnySecret
                ? Color.lerp(scheme.surfaceContainerLow, secretTint, 0.07)
                : scheme.surfaceContainerLow,
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
                            Icons.auto_awesome_motion_rounded,
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
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              row.seriesTitle,
                              style: textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.14,
                              ),
                            ),
                          ),
                          if (row.hasAnySecret)
                            Padding(
                              padding: const EdgeInsets.only(left: 6),
                              child: Icon(
                                Icons.auto_awesome_rounded,
                                size: 18,
                                color: secretTint.withValues(alpha: 0.88),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        row.summaryLine,
                        style: textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant.withValues(alpha: 0.9),
                          fontWeight: FontWeight.w500,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        row.brandIpLine,
                        style: textTheme.labelMedium?.copyWith(
                          color: scheme.onSurfaceVariant.withValues(
                            alpha: 0.68,
                          ),
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
