import 'package:blindbox_app/core/theme/app_spacing.dart';
import 'package:blindbox_app/core/theme/collectible_typography.dart';
import 'package:blindbox_app/features/catalog/presentation/figure_gallery/catalog_figure_gallery_adapters.dart';
import 'package:blindbox_app/features/catalog/presentation/figure_gallery/catalog_figure_gallery_sheet.dart';
import 'package:blindbox_app/features/collectible_relationship/application/collectible_relationship_providers.dart';
import 'package:blindbox_app/features/collectible_relationship/widgets/collectible_relationship_line.dart';
import 'package:blindbox_app/features/collection/application/collection_notifier.dart';
import 'package:blindbox_app/features/collection/application/shelf_emotional_providers.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/collection/domain/series_completion_resolution.dart';
import 'package:blindbox_app/features/collection/presentation/collection_vocabulary.dart';
import 'package:blindbox_app/features/collection/presentation/shelf_editorial_voice.dart';
import 'package:blindbox_app/features/collection/widgets/collection_progress_voice.dart';
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

    final resolution = resolveSeriesCompletion(series, snap.figureStates);
    final isComplete = resolution.isCompleted;
    final chasesHome = resolution.isMasterComplete;
    final scroll = CollectibleSheetScope.scrollControllerOf(context);
    final relationshipLine = ref.watch(
      relationshipHintForShelfSeriesProvider(seriesId),
    );
    final memoryReflection = ref.watch(
      collectionMemoryReflectionForSeriesProvider(seriesId),
    );
    final trailingMeta =
        CollectionProgressVoice.seriesFiguresSheetProgressMeta(resolution);
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
                  chasesHome: chasesHome,
                ),
              ),
            ),
          SliverPadding(
            padding: EdgeInsets.only(
              top: isComplete ? 14 : FeedRhythm.sheetFigureRailGap,
              bottom: AppSpacing.lg,
            ),
            sliver: SliverToBoxAdapter(
              child: _SeriesFigureGrid(
                series: series,
                snap: snap,
                resolution: resolution,
                onCycleFigure: notifier.cycleFigure,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SeriesFigureGrid extends StatelessWidget {
  const _SeriesFigureGrid({
    required this.series,
    required this.snap,
    required this.resolution,
    required this.onCycleFigure,
  });

  final ShelfSeries series;
  final CollectionSnapshot snap;
  final SeriesCompletionResolution resolution;
  final void Function(String figureId) onCycleFigure;

  @override
  Widget build(BuildContext context) {
    final regularFigures =
        series.figures.where((f) => !f.isSecret).toList(growable: false);
    final secretFigures =
        series.figures.where((f) => f.isSecret).toList(growable: false);

    if (secretFigures.isEmpty) {
      return _FigureCapsuleWrap(
        series: series,
        figures: series.figures,
        snap: snap,
        onCycleFigure: onCycleFigure,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (regularFigures.isNotEmpty) ...[
          const _FigureSheetSectionRule(),
          const SizedBox(height: 16),
          _FigureSheetSectionHeader(
            label: CollectionVocabulary.regularFigures,
            owned: resolution.regularOwnedCount,
            total: resolution.regularSlotCount,
          ),
          const SizedBox(height: 14),
          _FigureCapsuleWrap(
            series: series,
            figures: regularFigures,
            snap: snap,
            onCycleFigure: onCycleFigure,
          ),
        ],
        const SizedBox(height: 28),
        const _FigureSheetSectionRule(),
        const SizedBox(height: 16),
        _FigureSheetSectionHeader(
          label: CollectionVocabulary.secretFigures,
          owned: resolution.secretOwnedCount,
          total: resolution.secretSlotCount,
          showCrown: true,
          accent: true,
        ),
        const SizedBox(height: 24),
        _FigureCapsuleWrap(
          series: series,
          figures: secretFigures,
          snap: snap,
          onCycleFigure: onCycleFigure,
        ),
      ],
    );
  }
}

class _FigureSheetSectionRule extends StatelessWidget {
  const _FigureSheetSectionRule();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Divider(
      height: 1,
      thickness: 1,
      color: scheme.outlineVariant.withValues(alpha: 0.32),
    );
  }
}

class _FigureSheetSectionHeader extends StatelessWidget {
  const _FigureSheetSectionHeader({
    required this.label,
    required this.owned,
    required this.total,
    this.showCrown = false,
    this.accent = false,
  });

  final String label;
  final int owned;
  final int total;
  final bool showCrown;
  final bool accent;

  String get _displayLabel => '$label ($owned of $total)';

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final style = CollectibleTypography.shelfFigureSheetSectionLabel(
      textTheme,
      scheme,
      accent: accent,
    );

    return Semantics(
      header: true,
      label: _displayLabel,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (showCrown) ...[
            Text('👑', style: style.copyWith(fontSize: 13)),
            const SizedBox(width: 5),
          ],
          Text(_displayLabel, style: style),
        ],
      ),
    );
  }
}

class _FigureCapsuleWrap extends StatelessWidget {
  const _FigureCapsuleWrap({
    required this.series,
    required this.figures,
    required this.snap,
    required this.onCycleFigure,
  });

  final ShelfSeries series;
  final List<ShelfFigure> figures;
  final CollectionSnapshot snap;
  final void Function(String figureId) onCycleFigure;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Wrap(
        spacing: 14,
        runSpacing: 18,
        alignment: WrapAlignment.center,
        children: [
          for (final f in figures)
            FigureCapsuleCard(
              series: series,
              figure: f,
              tracked: snap.trackedOrDefault(f.id),
              onTap: () => onCycleFigure(f.id),
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
