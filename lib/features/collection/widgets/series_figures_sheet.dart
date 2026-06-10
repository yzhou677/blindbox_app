import 'package:blindbox_app/core/theme/app_spacing.dart';
import 'package:blindbox_app/features/catalog/presentation/figure_gallery/catalog_figure_gallery_adapters.dart';
import 'package:blindbox_app/features/catalog/presentation/figure_gallery/catalog_figure_gallery_sheet.dart';
import 'package:blindbox_app/features/collectible_relationship/application/collectible_relationship_providers.dart';
import 'package:blindbox_app/features/collectible_relationship/widgets/collectible_relationship_line.dart';
import 'package:blindbox_app/features/collection/application/collection_notifier.dart';
import 'package:blindbox_app/features/collection/application/shelf_emotional_providers.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/collection/presentation/shelf_editorial_voice.dart';
import 'package:blindbox_app/features/collection/presentation/collection_modal_overlays.dart';
import 'package:blindbox_app/features/collection/widgets/custom_series_form_sheet.dart';
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

void _openEditCustomSeries(
  BuildContext context,
  WidgetRef ref,
  ShelfSeries series,
) {
  showCollectionModalBottomSheet<void>(
    context: context,
    backgroundColor: Theme.of(context).colorScheme.surface,
    builder: (_, scroll) => CustomSeriesFormSheet.edit(
      initialSeries: series,
      onSubmit:
          ({
            required String seriesName,
            String? brand,
            String? ipDisplayName,
            String? customCoverImageUri,
            String? notes,
          }) {
            ref.read(collectionNotifierProvider.notifier).updateCustomSeries(
                  seriesId: series.id,
                  seriesName: seriesName,
                  brand: brand,
                  ipDisplayName: ipDisplayName,
                  customCoverImageUri: customCoverImageUri,
                  notes: notes,
                );
          },
      onFigureSubmit:
          ({
            required String figureId,
            required String name,
            required bool isSecret,
            String? rarityLabel,
            String? localImageUri,
          }) {
            ref.read(collectionNotifierProvider.notifier).updateCustomFigure(
                  seriesId: series.id,
                  figureId: figureId,
                  name: name,
                  isSecret: isSecret,
                  rarityLabel: rarityLabel,
                  localImageUri: localImageUri,
                );
          },
      onFigureAdd:
          ({
            required String name,
            required bool isSecret,
            String? rarityLabel,
            String? localImageUri,
          }) {
            ref.read(collectionNotifierProvider.notifier).addCustomFigure(
                  seriesId: series.id,
                  name: name,
                  isSecret: isSecret,
                  rarityLabel: rarityLabel,
                  localImageUri: localImageUri,
                );
          },
    ),
  );
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
    final relationshipLine = ref.watch(
      relationshipHintForShelfSeriesProvider(seriesId),
    );
    final memoryReflection = ref.watch(
      collectionMemoryReflectionForSeriesProvider(seriesId),
    );
    final trailingMeta = series.figureCount > 0
        ? '${progress.owned} of ${series.figureCount} on shelf'
        : null;
    final contextualLine =
        (relationshipLine != null && relationshipLine.isNotEmpty)
            ? relationshipLine
            : memoryReflection;

    return CollectibleSheetInsets(
      child: CollectibleSheetScrollView(
        controller: scroll,
        header: CollectibleSheetChrome(
          seriesTitle: series.name,
          brand: series.brand,
          ipLine: series.ipName,
          trailingMeta: trailingMeta,
        ),
        slivers: [
          if (series.isCustomLocal)
            SliverToBoxAdapter(
              child: Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => _openEditCustomSeries(context, ref, series),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Edit series'),
                ),
              ),
            ),
          if (contextualLine != null && contextualLine.isNotEmpty)
            SliverToBoxAdapter(
              child: CollectibleRelationshipLine(
                text: contextualLine,
                padding: const EdgeInsets.only(top: 10),
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
            padding: EdgeInsets.only(
              top: isComplete ? 14 : FeedRhythm.sheetFigureRailGap,
              bottom: AppSpacing.lg,
            ),
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
                    ShelfEditorialVoice.seriesCompleteBannerTitle(
                      chasesHome: chasesHome,
                    ),
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.1,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    ShelfEditorialVoice.seriesCompleteBannerSubtitle(
                      chasesHome: chasesHome,
                    ),
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
