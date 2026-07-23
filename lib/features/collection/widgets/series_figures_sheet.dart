import 'dart:async';

import 'package:blindbox_app/core/theme/app_spacing.dart';
import 'package:blindbox_app/core/theme/collectible_motion.dart';
import 'package:blindbox_app/core/theme/collectible_typography.dart';
import 'package:blindbox_app/features/catalog/presentation/figure_gallery/catalog_figure_gallery_adapters.dart';
import 'package:blindbox_app/features/catalog/presentation/figure_gallery/catalog_figure_gallery_sheet.dart';
import 'package:blindbox_app/features/collection/application/collection_notifier.dart';
import 'package:blindbox_app/features/collection/application/share_payload_builders/master_complete_share_payload_builder.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/collection/domain/series_completion_resolution.dart';
import 'package:blindbox_app/features/collection/presentation/collection_vocabulary.dart';
import 'package:blindbox_app/features/collection/presentation/shelf_editorial_voice.dart';
import 'package:blindbox_app/features/collection/widgets/collection_progress_voice.dart';
import 'package:blindbox_app/features/collection/widgets/figure_capsule_card.dart';
import 'package:blindbox_app/core/layout/feed_rhythm.dart';
import 'package:blindbox_app/features/sharing/presentation/share_card_preview.dart';
import 'package:blindbox_app/features/sharing/presentation/widgets/shelfy_collector_cards.dart';
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
class SeriesFiguresSheet extends ConsumerStatefulWidget {
  const SeriesFiguresSheet({
    super.key,
    required this.seriesId,
    this.matchedFigureId,
  });

  final String seriesId;

  /// When opened from recognition, scroll to and briefly highlight this figure.
  final String? matchedFigureId;

  @override
  ConsumerState<SeriesFiguresSheet> createState() => _SeriesFiguresSheetState();
}

class _SeriesFiguresSheetState extends ConsumerState<SeriesFiguresSheet> {
  static const _matchedLabel = 'Matched from your photo';

  final Map<String, GlobalKey> _figureKeys = {};
  var _matchHighlightVisible = false;
  Timer? _highlightTimer;

  @override
  void initState() {
    super.initState();
    final matchedId = widget.matchedFigureId?.trim();
    if (matchedId != null && matchedId.isNotEmpty) {
      _matchHighlightVisible = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _revealMatched(matchedId));
      _highlightTimer = Timer(const Duration(milliseconds: 2400), () {
        if (mounted) setState(() => _matchHighlightVisible = false);
      });
    }
  }

  @override
  void dispose() {
    _highlightTimer?.cancel();
    super.dispose();
  }

  Future<void> _revealMatched(String figureId) async {
    if (!mounted) return;
    final key = _figureKeys.putIfAbsent(figureId, GlobalKey.new);
    final ctx = key.currentContext;
    if (ctx == null) return;
    await Scrollable.ensureVisible(
      ctx,
      alignment: 0.2,
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : CollectibleMotion.sectionReveal,
      curve: CollectibleMotion.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final snap = ref.watch(collectionNotifierProvider);
    final notifier = ref.read(collectionNotifierProvider.notifier);
    final series = _findSeries(snap, widget.seriesId);
    if (series == null) return const SizedBox.shrink();

    final resolution = resolveSeriesCompletion(series, snap.figureStates);
    final isComplete = resolution.isCompleted;
    final chasesHome = resolution.isMasterComplete;
    final completionBannerState = _completionBannerState(resolution);
    final scroll = CollectibleSheetScope.scrollControllerOf(context);
    final trailingMeta = CollectionProgressVoice.seriesFiguresSheetProgressMeta(
      resolution,
    );
    final seriesNote = series.isCustomLocal ? series.notes?.trim() : null;
    final masterSharePayload = chasesHome
        ? buildMasterCompleteSharePayload(
            series: series,
            figureStates: snap.figureStates,
          )
        : null;
    final matchedId = widget.matchedFigureId?.trim();

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
          if (seriesNote != null && seriesNote.isNotEmpty)
            SliverToBoxAdapter(
              child: _SeriesNoteText(note: seriesNote, topPadding: 16),
            ),
          if (matchedId != null &&
              matchedId.isNotEmpty &&
              _matchHighlightVisible)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  _matchedLabel,
                  key: const Key('recognition-matched-figure-label'),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          if (isComplete)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(top: 14),
                child: _SeriesCompleteBanner(
                  state: completionBannerState,
                  onShare: masterSharePayload == null
                      ? null
                      : () => showShareCardPreview(
                          context: context,
                          card: MasterCompleteShareCard(
                            payload: masterSharePayload,
                          ),
                          basename: 'shelfy-master-card',
                          loadingLabel: 'Finishing the Master Card...',
                          previewTitle: 'Master Card',
                        ),
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
                matchedFigureId: matchedId,
                matchHighlightVisible: _matchHighlightVisible,
                figureKeys: _figureKeys,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

SeriesCompletionBannerState _completionBannerState(
  SeriesCompletionResolution resolution,
) {
  if (resolution.isMasterComplete) {
    return SeriesCompletionBannerState.masterComplete;
  }
  if (resolution.secretSlotCount > 0) {
    return SeriesCompletionBannerState.completeWithSecretsRemaining;
  }
  return SeriesCompletionBannerState.completeNoSecrets;
}

class _SeriesNoteText extends StatelessWidget {
  const _SeriesNoteText({required this.note, required this.topPadding});

  final String note;
  final double topPadding;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: EdgeInsets.only(top: topPadding),
      child: Text(
        note,
        style: textTheme.bodyMedium?.copyWith(
          color: scheme.onSurfaceVariant.withValues(alpha: 0.78),
          fontStyle: FontStyle.italic,
          height: 1.45,
        ),
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
    this.matchedFigureId,
    this.matchHighlightVisible = false,
    this.figureKeys = const {},
  });

  final ShelfSeries series;
  final CollectionSnapshot snap;
  final SeriesCompletionResolution resolution;
  final void Function(String figureId) onCycleFigure;
  final String? matchedFigureId;
  final bool matchHighlightVisible;
  final Map<String, GlobalKey> figureKeys;

  @override
  Widget build(BuildContext context) {
    final regularFigures = series.figures
        .where((f) => !f.isSecret)
        .toList(growable: false);
    final secretFigures = series.figures
        .where((f) => f.isSecret)
        .toList(growable: false);

    if (secretFigures.isEmpty) {
      return _FigureCapsuleWrap(
        series: series,
        figures: series.figures,
        snap: snap,
        onCycleFigure: onCycleFigure,
        matchedFigureId: matchedFigureId,
        matchHighlightVisible: matchHighlightVisible,
        figureKeys: figureKeys,
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
            matchedFigureId: matchedFigureId,
            matchHighlightVisible: matchHighlightVisible,
            figureKeys: figureKeys,
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
          matchedFigureId: matchedFigureId,
          matchHighlightVisible: matchHighlightVisible,
          figureKeys: figureKeys,
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
            Icon(
              Icons.emoji_events_rounded,
              size: 14,
              color: scheme.primary.withValues(alpha: 0.78),
            ),
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
    this.matchedFigureId,
    this.matchHighlightVisible = false,
    this.figureKeys = const {},
  });

  final ShelfSeries series;
  final List<ShelfFigure> figures;
  final CollectionSnapshot snap;
  final void Function(String figureId) onCycleFigure;
  final String? matchedFigureId;
  final bool matchHighlightVisible;
  final Map<String, GlobalKey> figureKeys;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: double.infinity,
      child: Wrap(
        spacing: 14,
        runSpacing: 18,
        alignment: WrapAlignment.center,
        children: [
          for (final f in figures)
            Builder(
              builder: (context) {
                final isMatched =
                    matchedFigureId != null &&
                    matchedFigureId!.isNotEmpty &&
                    f.id == matchedFigureId;
                final capsule = FigureCapsuleCard(
                  key: isMatched
                      ? figureKeys.putIfAbsent(f.id, GlobalKey.new)
                      : ValueKey<String>(f.id),
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
                );
                if (!isMatched || !matchHighlightVisible) return capsule;
                return AnimatedContainer(
                  duration: CollectibleMotion.crossfade,
                  curve: CollectibleMotion.easeOut,
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: scheme.primary.withValues(alpha: 0.42),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: scheme.primary.withValues(alpha: 0.12),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: capsule,
                );
              },
            ),
        ],
      ),
    );
  }
}

class _SeriesCompleteBanner extends StatelessWidget {
  const _SeriesCompleteBanner({required this.state, this.onShare});

  final SeriesCompletionBannerState state;
  final VoidCallback? onShare;

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
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Icon(
                state == SeriesCompletionBannerState.masterComplete
                    ? Icons.emoji_events_rounded
                    : Icons.check_circle_outline_rounded,
                size: 22,
                color: scheme.primary.withValues(alpha: 0.85),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ShelfEditorialVoice.seriesCompleteBannerTitle(state),
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.1,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    ShelfEditorialVoice.seriesCompleteBannerSubtitle(state),
                    style: textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant.withValues(alpha: 0.85),
                      height: 1.3,
                    ),
                  ),
                  if (onShare != null) ...[
                    const SizedBox(height: 10),
                    _InlineShareAction(
                      label: 'Share Master Card',
                      onPressed: onShare!,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InlineShareAction extends StatelessWidget {
  const _InlineShareAction({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(
        Icons.ios_share_rounded,
        size: 16,
        color: scheme.primary.withValues(alpha: 0.72),
      ),
      label: Text(
        label,
        style: textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w600,
          color: scheme.onSurfaceVariant.withValues(alpha: 0.78),
        ),
      ),
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: scheme.primary.withValues(alpha: 0.24)),
        backgroundColor: scheme.surface.withValues(alpha: 0.18),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        minimumSize: const Size(0, 34),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}
