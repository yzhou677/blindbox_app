import 'package:blindbox_app/core/theme/app_spacing.dart';
import 'package:blindbox_app/core/theme/collectible_typography.dart';
import 'package:blindbox_app/features/catalog/presentation/figure_gallery/catalog_figure_gallery_adapters.dart';
import 'package:blindbox_app/features/catalog/presentation/figure_gallery/catalog_figure_gallery_sheet.dart';
import 'package:blindbox_app/features/collection/application/collection_notifier.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/collection/widgets/figure_capsule_card.dart';
import 'package:blindbox_app/core/layout/feed_rhythm.dart';
import 'package:blindbox_app/shared/widgets/collectible_bottom_sheet.dart';
import 'package:blindbox_app/shared/widgets/collectible_sheet_chrome.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

ShelfSeries? _findSeries(CollectionSnapshot snap, String seriesId) {
  for (final s in snap.shelfSeries) {
    if (s.id == seriesId) return s;
  }
  return null;
}

/// Figure-first sheet — replaces numeric slot chips.
class SeriesFiguresSheet extends ConsumerWidget {
  const SeriesFiguresSheet({super.key, required this.seriesId});

  final String seriesId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snap = ref.watch(collectionNotifierProvider);
    final notifier = ref.read(collectionNotifierProvider.notifier);
    final series = _findSeries(snap, seriesId);
    if (series == null) return const SizedBox.shrink();

    final progress = progressForSeries(series, snap.figureStates);
    final isComplete =
        series.figureCount > 0 && progress.owned >= series.figureCount;
    final secrets = series.figures.where((f) => f.isSecret).toList();
    final chasesHome =
        secrets.isNotEmpty &&
        secrets.every((f) => snap.trackedOrDefault(f.id).owned);
    final scroll = CollectibleSheetScope.scrollControllerOf(context);

    return CollectibleSheetInsets(
      child: CustomScrollView(
        controller: scroll,
        physics: collectibleSheetScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: CollectibleSheetChrome(
              seriesTitle: series.name,
              brand: series.brand,
              ipLine: series.ipName,
              padding: EdgeInsets.zero,
            ),
          ),
          if (isComplete)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(top: 14),
                child: _SeriesCompleteBanner(
                  chasesHome: chasesHome && secrets.isNotEmpty,
                ),
              ),
            ),
          SliverPadding(
            padding: const EdgeInsets.only(top: 18, bottom: AppSpacing.lg),
            sliver: SliverToBoxAdapter(
              child: SizedBox(
                width: double.infinity,
                child: Wrap(
                  spacing: 14,
                  runSpacing: 18,
                  alignment: WrapAlignment.center,
                  children: [
                    for (final f in series.figures)
                      FigureCapsuleCard(
                        series: series,
                        figure: f,
                        tracked: snap.trackedOrDefault(f.id),
                        onTap: () => notifier.cycleFigure(f.id),
                        onBrowseFigure: () {
                          final index = series.figures.indexWhere(
                            (fig) => fig.id == f.id,
                          );
                          showCatalogFigureGallery(
                            context,
                            items: catalogGalleryItemsFromShelfSeries(series),
                            initialIndex: index < 0 ? 0 : index,
                            seriesTitle: series.name,
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SeriesCompleteBanner extends StatelessWidget {
  const _SeriesCompleteBanner({required this.chasesHome});

  final bool chasesHome;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [
            Color.lerp(
              scheme.primaryContainer,
              const Color(0xFFFFF6E8),
              isDark ? 0.15 : 0.45,
            )!.withValues(alpha: isDark ? 0.5 : 0.72),
            scheme.surfaceContainerHighest.withValues(alpha: 0.35),
          ],
        ),
        border: Border.all(
          color: Color.lerp(
            scheme.primary,
            const Color(0xFFE8C547),
            0.3,
          )!.withValues(alpha: 0.45),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE8C547).withValues(alpha: 0.12),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Icon(
              Icons.check_circle_outline_rounded,
              size: 22,
              color: scheme.primary.withValues(alpha: 0.85),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    chasesHome
                        ? 'Whole series — chase home'
                        : 'This series feels complete',
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.1,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    chasesHome
                        ? 'A rare, quiet moment for the shelf.'
                        : 'Every figure has found its place here.',
                    style: textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant.withValues(alpha: 0.85),
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
