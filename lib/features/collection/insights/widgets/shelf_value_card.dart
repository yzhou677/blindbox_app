import 'package:blindbox_app/core/theme/app_spacing.dart';
import 'package:blindbox_app/core/theme/collectible_shape.dart';
import 'package:blindbox_app/features/catalog/presentation/catalog_image_display.dart';
import 'package:blindbox_app/features/catalog/presentation/figure_gallery/catalog_figure_gallery_adapters.dart';
import 'package:blindbox_app/features/catalog/presentation/figure_gallery/catalog_figure_gallery_sheet.dart';
import 'package:blindbox_app/features/collection/application/collection_notifier.dart';
import 'package:blindbox_app/features/collection/insights/application/collection_value_providers.dart';
import 'package:blindbox_app/features/collection/insights/domain/shelf_value_summary.dart';
import 'package:blindbox_app/features/collection/insights/widgets/shelf_value_info_sheet.dart';
import 'package:blindbox_app/features/market/utils/market_format.dart';
import 'package:blindbox_app/shared/widgets/app_image_shimmer.dart';
import 'package:blindbox_app/shared/widgets/catalog_image_from_key.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Card displayed on [CollectionInsightsScreen] with three sections:
///
/// 1. Estimated total value + coverage
/// 2. Top 5 most-valuable owned figures
/// 3. Per-series breakdown (collapsed by default)
class ShelfValueCard extends ConsumerStatefulWidget {
  const ShelfValueCard({super.key});

  @override
  ConsumerState<ShelfValueCard> createState() => _ShelfValueCardState();
}

class _ShelfValueCardState extends ConsumerState<ShelfValueCard> {
  bool _seriesExpanded = false;

  @override
  Widget build(BuildContext context) {
    final asyncValue = ref.watch(collectionValueProvider);
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: CollectibleShape.matRadius,
        color: scheme.surfaceContainerLow.withValues(alpha: 0.6),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.32),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.pageHorizontal,
          AppSpacing.lg,
          AppSpacing.pageHorizontal,
          AppSpacing.lg,
        ),
        child: asyncValue.when(
          loading: () => const _ShelfValueSkeleton(),
          error: (err, _) => const _ShelfValueError(),
          data: (summary) {
            if (!summary.hasAnyValue) {
              return _ShelfValueEmpty(scheme: scheme, textTheme: textTheme);
            }
            return _ShelfValueContent(
              summary: summary,
              scheme: scheme,
              textTheme: textTheme,
              seriesExpanded: _seriesExpanded,
              onSeriesToggle: () =>
                  setState(() => _seriesExpanded = !_seriesExpanded),
              onFigureTap: (fig) => _openGallery(context, fig),
            );
          },
        ),
      ),
    );
  }

  void _openGallery(BuildContext context, ValuedFigure fig) {
    final snap = ref.read(collectionNotifierProvider);
    final series = snap.shelfSeries.where((s) => s.id == fig.seriesId).firstOrNull;
    if (series == null) return;

    final items = catalogGalleryItemsFromShelfSeries(series);
    final initialIndex = series.figures.indexWhere(
      (f) => f.id == fig.shelfFigureId,
    );
    showCatalogFigureGallery(
      context,
      items: items,
      initialIndex: initialIndex < 0 ? 0 : initialIndex,
      seriesTitle: series.name,
    );
  }
}

// ---------------------------------------------------------------------------
// Content
// ---------------------------------------------------------------------------

class _ShelfValueContent extends StatelessWidget {
  const _ShelfValueContent({
    required this.summary,
    required this.scheme,
    required this.textTheme,
    required this.seriesExpanded,
    required this.onSeriesToggle,
    required this.onFigureTap,
  });

  final ShelfValueSummary summary;
  final ColorScheme scheme;
  final TextTheme textTheme;
  final bool seriesExpanded;
  final VoidCallback onSeriesToggle;
  final void Function(ValuedFigure fig) onFigureTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          title: 'Shelf Value',
          scheme: scheme,
          textTheme: textTheme,
          onInfoTap: () => showShelfValueInfoSheet(context),
        ),
        const SizedBox(height: AppSpacing.sm),
        _ValueOverview(summary: summary, scheme: scheme, textTheme: textTheme),
        if (summary.topFigures.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          _SectionHeader(
            title: 'Most Valuable',
            scheme: scheme,
            textTheme: textTheme,
          ),
          const SizedBox(height: AppSpacing.xs),
          for (var i = 0; i < summary.topFigures.length; i++) ...[
            if (i > 0) const SizedBox(height: 2),
            _FigureValueRow(
              rank: i + 1,
              fig: summary.topFigures[i],
              scheme: scheme,
              textTheme: textTheme,
              onTap: () => onFigureTap(summary.topFigures[i]),
            ),
          ],
        ],
        if (summary.seriesBreakdown.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          _SeriesSection(
            entries: summary.seriesBreakdown,
            expanded: seriesExpanded,
            onToggle: onSeriesToggle,
            scheme: scheme,
            textTheme: textTheme,
          ),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Section 1 — Overview
// ---------------------------------------------------------------------------

class _ValueOverview extends StatelessWidget {
  const _ValueOverview({
    required this.summary,
    required this.scheme,
    required this.textTheme,
  });

  final ShelfValueSummary summary;
  final ColorScheme scheme;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    final valueLabel = '~${formatShelfValueUsd(summary.totalValueUsd)}';
    final coverageLabel = summary.coverageLabel;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          valueLabel,
          style: textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: scheme.onSurface.withValues(alpha: 0.92),
            height: 1.1,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          coverageLabel,
          style: textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: 10),
        _CoverageBar(
          percent: summary.coveragePercent,
          scheme: scheme,
          textTheme: textTheme,
        ),
      ],
    );
  }
}

class _CoverageBar extends StatelessWidget {
  const _CoverageBar({
    required this.percent,
    required this.scheme,
    required this.textTheme,
  });

  final int percent;
  final ColorScheme scheme;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    final fraction = (percent / 100).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: fraction,
            minHeight: 5,
            backgroundColor: scheme.outlineVariant.withValues(alpha: 0.25),
            valueColor: AlwaysStoppedAnimation<Color>(
              scheme.primary.withValues(alpha: 0.7),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '$percent% coverage',
          style: textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant.withValues(alpha: 0.6),
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Section 2 — Top figures
// ---------------------------------------------------------------------------

class _FigureValueRow extends StatelessWidget {
  const _FigureValueRow({
    required this.rank,
    required this.fig,
    required this.scheme,
    required this.textTheme,
    required this.onTap,
  });

  final int rank;
  final ValuedFigure fig;
  final ColorScheme scheme;
  final TextTheme textTheme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final valueLabel = fig.isSeriesEstimate
        ? '~${formatShelfValueUsd(fig.estimatedValueUsd)}'
        : formatShelfValueUsd(fig.estimatedValueUsd);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          children: [
            SizedBox(
              width: 22,
              child: Text(
                '$rank',
                style: textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.55),
                  fontWeight: FontWeight.w600,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(width: 8),
            _FigureThumb(imageKey: fig.imageKey, name: fig.name),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                fig.name,
                style: textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurface.withValues(alpha: 0.88),
                  height: 1.2,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              valueLabel,
              style: textTheme.bodyMedium?.copyWith(
                color: scheme.onSurface.withValues(alpha: 0.75),
                fontWeight: FontWeight.w600,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FigureThumb extends StatelessWidget {
  const _FigureThumb({required this.imageKey, required this.name});

  final String? imageKey;
  final String name;

  static const double _size = 36;

  @override
  Widget build(BuildContext context) {
    final key = imageKey?.trim();
    if (key == null || key.isEmpty) {
      return Container(
        width: _size,
        height: _size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
        ),
        child: Center(
          child: Text(
            name.isNotEmpty ? name[0].toUpperCase() : '?',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(
                context,
              ).colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
            ),
          ),
        ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: CatalogImageFromKey(
        imageKey: key,
        name: name,
        seedKey: key,
        displayMode: CatalogImageDisplayMode.figureThumb,
        compact: true,
        width: _size,
        height: _size,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Section 3 — By series
// ---------------------------------------------------------------------------

class _SeriesSection extends StatelessWidget {
  const _SeriesSection({
    required this.entries,
    required this.expanded,
    required this.onToggle,
    required this.scheme,
    required this.textTheme,
  });

  final List<SeriesValueEntry> entries;
  final bool expanded;
  final VoidCallback onToggle;
  final ColorScheme scheme;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: onToggle,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: _SectionHeader(
                    title: 'By Series',
                    scheme: scheme,
                    textTheme: textTheme,
                  ),
                ),
                Icon(
                  expanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  size: 20,
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.55),
                ),
              ],
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          child: expanded
              ? Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xs),
                  child: Column(
                    children: [
                      for (var i = 0; i < entries.length; i++) ...[
                        if (i > 0)
                          Divider(
                            height: 1,
                            thickness: 0.5,
                            color: scheme.outlineVariant.withValues(
                              alpha: 0.2,
                            ),
                          ),
                        _SeriesValueRow(
                          entry: entries[i],
                          scheme: scheme,
                          textTheme: textTheme,
                        ),
                      ],
                    ],
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

class _SeriesValueRow extends StatelessWidget {
  const _SeriesValueRow({
    required this.entry,
    required this.scheme,
    required this.textTheme,
  });

  final SeriesValueEntry entry;
  final ColorScheme scheme;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    final valueLabel = entry.hasSeriesEstimates
        ? '~${formatShelfValueUsd(entry.totalValueUsd)}'
        : formatShelfValueUsd(entry.totalValueUsd);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.seriesName,
                  style: textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurface.withValues(alpha: 0.88),
                    height: 1.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${entry.valuedFigureCount} of ${entry.ownedFigureCount} figures valued',
                  style: textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            valueLabel,
            style: textTheme.bodyMedium?.copyWith(
              color: scheme.onSurface.withValues(alpha: 0.75),
              fontWeight: FontWeight.w600,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.scheme,
    required this.textTheme,
    this.onInfoTap,
  });

  final String title;
  final ColorScheme scheme;
  final TextTheme textTheme;
  final VoidCallback? onInfoTap;

  @override
  Widget build(BuildContext context) {
    final titleStyle = textTheme.titleSmall?.copyWith(
      color: scheme.onSurface.withValues(alpha: 0.75),
      fontWeight: FontWeight.w700,
      letterSpacing: 0.4,
    );

    if (onInfoTap == null) {
      return Text(title, style: titleStyle);
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(title, style: titleStyle),
        const SizedBox(width: 6),
        Semantics(
          button: true,
          label: kShelfValueInfoSemanticsLabel,
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: onInfoTap,
              customBorder: const CircleBorder(),
              child: SizedBox(
                width: 40,
                height: 40,
                child: Center(
                  child: Icon(
                    Icons.info_outline,
                    size: 18,
                    color: scheme.onSurfaceVariant.withValues(alpha: 0.55),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Empty / loading / error states
// ---------------------------------------------------------------------------

class _ShelfValueEmpty extends StatelessWidget {
  const _ShelfValueEmpty({required this.scheme, required this.textTheme});

  final ColorScheme scheme;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Shelf Value',
          style: textTheme.titleSmall?.copyWith(
            color: scheme.onSurface.withValues(alpha: 0.75),
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'No market data available for your figures yet.',
          style: textTheme.bodyMedium?.copyWith(
            color: scheme.onSurfaceVariant.withValues(alpha: 0.65),
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

class _ShelfValueSkeleton extends StatelessWidget {
  const _ShelfValueSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          height: 14,
          child: AppImageShimmer(borderRadius: BorderRadius.circular(6)),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: 140,
          height: 34,
          child: AppImageShimmer(borderRadius: BorderRadius.circular(8)),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          height: 5,
          child: AppImageShimmer(borderRadius: BorderRadius.circular(4)),
        ),
      ],
    );
  }
}

class _ShelfValueError extends StatelessWidget {
  const _ShelfValueError();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Text(
      'Could not load shelf value.',
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: scheme.onSurfaceVariant.withValues(alpha: 0.55),
      ),
    );
  }
}
