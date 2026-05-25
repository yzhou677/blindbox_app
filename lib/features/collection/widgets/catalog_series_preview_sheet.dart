import 'package:blindbox_app/core/theme/app_spacing.dart';
import 'package:blindbox_app/core/theme/collectible_typography.dart';
import 'package:blindbox_app/features/catalog/presentation/catalog_image_display.dart';
import 'package:blindbox_app/features/catalog/presentation/figure_gallery/catalog_figure_gallery_adapters.dart';
import 'package:blindbox_app/features/catalog/presentation/figure_gallery/catalog_figure_gallery_sheet.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/collection/presentation/catalog_search_row_summary.dart';
import 'package:blindbox_app/features/collection/presentation/figure_secret_rarity_style.dart';
import 'package:blindbox_app/shared/widgets/catalog_image_from_key.dart';
import 'package:blindbox_app/core/layout/feed_rhythm.dart';
import 'package:blindbox_app/core/theme/app_radii.dart';
import 'package:blindbox_app/shared/widgets/collectible_bottom_sheet.dart';
import 'package:blindbox_app/shared/widgets/collectible_sheet_chrome.dart';
import 'package:blindbox_app/features/collectible_relationship/application/collectible_relationship_providers.dart';
import 'package:blindbox_app/features/collectible_relationship/widgets/collectible_relationship_line.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Read-only catalog lineup preview before adding a series to the shelf.
class CatalogSeriesPreviewSheet extends ConsumerWidget {
  const CatalogSeriesPreviewSheet({
    super.key,
    required this.series,
    required this.onAdd,
    this.showAddButton = true,
  });

  final CatalogSeries series;
  final VoidCallback onAdd;
  final bool showAddButton;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final hasChase = series.figures.any((f) => f.isSecret);
    final figureLine = catalogSearchRowSummary(
      figureCount: series.figureCount,
      hasChase: hasChase,
      matchedFigureNames: const {},
    );
    final scroll = CollectibleSheetScope.scrollControllerOf(context);
    final relationshipLine = ref.watch(
      relationshipHintForCatalogSeriesProvider(series.templateId),
    );

    return CollectibleSheetInsets(
      extraBottom: 0,
      child: CollectibleSheetScrollView(
        controller: scroll,
        slivers: [
        SliverToBoxAdapter(
          child: CollectibleSheetChrome(
            seriesTitle: series.name,
            brand: series.brand,
            ipLine: series.ipName,
            trailingMeta: figureLine,
          ),
        ),
        if (relationshipLine != null && relationshipLine.isNotEmpty)
          SliverToBoxAdapter(
            child: CollectibleRelationshipLine(
              text: relationshipLine,
              padding: const EdgeInsets.only(top: 10),
            ),
          ),
        SliverPadding(
          padding: const EdgeInsets.only(
            top: FeedRhythm.sheetFigureRailGap,
            bottom: AppSpacing.sm,
          ),
          sliver: SliverList.separated(
            itemCount: series.figures.length,
            separatorBuilder: (context, index) => const SizedBox(height: 14),
            itemBuilder: (context, i) {
              final f = series.figures[i];
              return _PreviewFigureRow(
                figure: f,
                accent: series.shelfAccent,
                onTap: () {
                  final items = catalogGalleryItemsFromCatalogSeries(series);
                  showCatalogFigureGallery(
                    context,
                    items: items,
                    initialIndex: i,
                    seriesTitle: series.name,
                  );
                },
              );
            },
          ),
        ),
        if (showAddButton)
          SliverToBoxAdapter(
            child: Material(
              color: scheme.surface,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: scheme.outlineVariant.withValues(alpha: 0.28),
                    ),
                  ),
                ),
                child: Padding(
                  padding: EdgeInsets.only(
                    left: 0,
                    right: 0,
                    top: 10,
                    bottom: MediaQuery.paddingOf(context).bottom + 8,
                  ),
                  child: FilledButton(
                    onPressed: () {
                      onAdd();
                      Navigator.of(context).pop();
                    },
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: AppRadii.matRadius,
                      ),
                    ),
                    child: const Text('Add to shelf'),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewFigureRow extends StatelessWidget {
  const _PreviewFigureRow({
    required this.figure,
    required this.accent,
    required this.onTap,
  });

  final CatalogFigure figure;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final secretLook = FigureSecretRarityStyle.resolve(
      isSecret: figure.isSecret,
      rarityLabel: figure.isSecret ? figure.rarity : null,
      isDark: isDark,
    );
    final rowBase = scheme.surfaceContainerLow;
    final rowColor = secretLook != null
        ? secretLook.cardTint(rowBase)
        : rowBase;

    return Material(
      color: rowColor,
      borderRadius: AppRadii.matRadius,
      shadowColor: secretLook?.accent.withValues(alpha: 0.12),
      elevation: secretLook != null ? 0.5 : 0,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadii.matRadius,
        child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
        child: Row(
          children: [
            CatalogImageSlot(
              displayMode: CatalogImageDisplayMode.figureThumb,
              child: (figure.catalogImageKey?.trim().isNotEmpty ?? false)
                  ? CatalogImageFromKey(
                      imageKey: figure.catalogImageKey!,
                      name: figure.name,
                      seedKey: figure.templateFigureId,
                      isSecret: figure.isSecret,
                      compact: true,
                      displayMode: CatalogImageDisplayMode.figureThumb,
                      borderRadius: BorderRadius.zero,
                    )
                  : ColoredBox(
                      color: scheme.surfaceContainerHighest.withValues(
                        alpha: 0.5,
                      ),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    figure.name,
                    style: CollectibleTypography.figureCaption(
                      textTheme,
                      scheme,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    figure.rarity,
                    style: CollectibleTypography.figureMeta(textTheme, scheme),
                  ),
                ],
              ),
            ),
            if (figure.isSecret)
              Icon(
                Icons.star_rounded,
                size: 20,
                color: (secretLook?.accent ?? accent).withValues(alpha: 0.88),
              ),
            Icon(
              Icons.chevron_right_rounded,
              size: 22,
              color: scheme.onSurfaceVariant.withValues(alpha: 0.45),
            ),
          ],
        ),
      ),
      ),
    );
  }
}
