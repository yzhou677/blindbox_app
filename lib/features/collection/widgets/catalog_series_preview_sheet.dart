import 'package:blindbox_app/core/theme/app_spacing.dart';
import 'package:blindbox_app/core/theme/collectible_typography.dart';
import 'package:blindbox_app/features/catalog/presentation/catalog_image_display.dart';
import 'package:blindbox_app/features/catalog/presentation/figure_gallery/catalog_figure_gallery_adapters.dart';
import 'package:blindbox_app/features/catalog/presentation/figure_gallery/catalog_figure_gallery_sheet.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/collection/presentation/collection_series_shelf_cta_presentation.dart';
import 'package:blindbox_app/features/collection/presentation/catalog_search_row_summary.dart';
import 'package:blindbox_app/features/collection/presentation/figure_secret_rarity_style.dart';
import 'package:blindbox_app/features/collection/widgets/catalog_series_preview_warm.dart';
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
class CatalogSeriesPreviewSheet extends ConsumerStatefulWidget {
  const CatalogSeriesPreviewSheet({
    super.key,
    required this.series,
    required this.shelfCta,
    required this.onAdd,
  });

  final CatalogSeries series;
  final CollectionSeriesShelfCtaPresentation shelfCta;
  final VoidCallback onAdd;

  @override
  ConsumerState<CatalogSeriesPreviewSheet> createState() =>
      _CatalogSeriesPreviewSheetState();
}

class _CatalogSeriesPreviewSheetState
    extends ConsumerState<CatalogSeriesPreviewSheet> {
  static const double _stickyActionBarReserve = 92;

  @override
  void initState() {
    super.initState();
    CatalogSeriesPreviewWarm.schedule(context, widget.series);
  }

  @override
  Widget build(BuildContext context) {
    final series = widget.series;
    final shelfCta = widget.shelfCta;
    final onAdd = widget.onAdd;
    final scheme = Theme.of(context).colorScheme;
    final hasChase = series.figures.any((f) => f.isSecret);
    final figureLine = catalogSearchRowSummary(
      figureCount: series.figureCount,
      hasChase: hasChase,
      matchedFigureNames: const {},
    );
    final scroll = CollectibleSheetScope.scrollControllerOf(context);
    final galleryItems = catalogGalleryItemsFromCatalogSeries(series);

    return CollectibleSheetInsets(
      extraBottom: 0,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: CollectibleSheetScrollView(
              controller: scroll,
              header: CollectibleSheetChrome(
                seriesTitle: series.name,
                brand: series.brand,
                ipLine: series.ipName,
                trailingMeta: figureLine,
              ),
              slivers: [
                SliverToBoxAdapter(
                  child: _DeferredPreviewRelationshipLine(
                    templateId: series.templateId,
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.only(
                    top: FeedRhythm.sheetFigureRailGap,
                    bottom: AppSpacing.sm,
                  ),
                  sliver: SliverList.separated(
                    itemCount: series.figures.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 14),
                    itemBuilder: (context, i) {
                      final f = series.figures[i];
                      return _PreviewFigureRow(
                        key: ValueKey<String>(f.templateFigureId),
                        figure: f,
                        figureIndex: i,
                        accent: series.shelfAccent,
                        onTap: () {
                          showCatalogFigureGallery(
                            context,
                            items: galleryItems,
                            initialIndex: i,
                            seriesTitle: series.name,
                          );
                        },
                      );
                    },
                  ),
                ),
                const SliverToBoxAdapter(
                  child: SizedBox(height: _stickyActionBarReserve),
                ),
              ],
            ),
          ),
          Material(
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
                padding: const EdgeInsets.only(top: 10, bottom: 8),
                child: Semantics(
                  button: true,
                  enabled: shelfCta.enabled,
                  label: shelfCta.semanticsLabel,
                  child: shelfCta.isAddable
                      ? FilledButton.icon(
                          key: const ValueKey<String>(
                            'catalog-preview-add-cta',
                          ),
                          onPressed: () {
                            onAdd();
                            Navigator.of(context).pop();
                          },
                          icon: Icon(shelfCta.icon, size: 20),
                          label: Text(shelfCta.label),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: AppRadii.matRadius,
                            ),
                          ),
                        )
                      : FilledButton.tonal(
                          key: const ValueKey<String>(
                            'catalog-preview-owned-cta',
                          ),
                          onPressed: null,
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            foregroundColor: scheme.onSurfaceVariant.withValues(
                              alpha: 0.85,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: AppRadii.matRadius,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(shelfCta.icon, size: 20),
                              const SizedBox(width: 8),
                              Text(shelfCta.label),
                            ],
                          ),
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

/// Defers relationship index work until after the sheet's first frame paints.
class _DeferredPreviewRelationshipLine extends ConsumerStatefulWidget {
  const _DeferredPreviewRelationshipLine({required this.templateId});

  final String templateId;

  @override
  ConsumerState<_DeferredPreviewRelationshipLine> createState() =>
      _DeferredPreviewRelationshipLineState();
}

class _DeferredPreviewRelationshipLineState
    extends ConsumerState<_DeferredPreviewRelationshipLine> {
  var _ready = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _ready = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) return const SizedBox.shrink();
    final relationshipLine = ref.watch(
      relationshipHintForCatalogSeriesProvider(widget.templateId),
    );
    if (relationshipLine == null || relationshipLine.isEmpty) {
      return const SizedBox.shrink();
    }
    return CollectibleRelationshipLine(
      text: relationshipLine,
      padding: const EdgeInsets.only(top: 10),
    );
  }
}

class _PreviewFigureRow extends StatelessWidget {
  const _PreviewFigureRow({
    super.key,
    required this.figure,
    required this.figureIndex,
    required this.accent,
    required this.onTap,
  });

  static const _resolveBatchSize = 4;

  final CatalogFigure figure;
  final int figureIndex;
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

    return RepaintBoundary(
      child: Material(
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
                          deferInitialResolve: true,
                          resolveStaggerBatch: figureIndex ~/ _resolveBatchSize,
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
                        style: CollectibleTypography.figureMeta(
                          textTheme,
                          scheme,
                        ),
                      ),
                    ],
                  ),
                ),
                if (figure.isSecret)
                  Icon(
                    Icons.star_rounded,
                    size: 20,
                    color: (secretLook?.accent ?? accent).withValues(
                      alpha: 0.88,
                    ),
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
      ),
    );
  }
}
