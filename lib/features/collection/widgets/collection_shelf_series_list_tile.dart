import 'package:blindbox_app/core/layout/feed_rhythm.dart';
import 'package:blindbox_app/core/theme/app_radii.dart';
import 'package:blindbox_app/core/theme/app_spacing.dart';
import 'package:blindbox_app/core/theme/collectible_typography.dart';
import 'package:blindbox_app/core/theme/shelfy_symbols.dart';
import 'package:blindbox_app/features/catalog/catalog_bundle.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/collection/domain/series_completion_resolution.dart';
import 'package:blindbox_app/features/collection/presentation/collection_card_tokens.dart';
import 'package:blindbox_app/features/collection/presentation/collection_series_thumbnail.dart';
import 'package:blindbox_app/features/collection/presentation/collection_shelf_card_content.dart';
import 'package:blindbox_app/features/collection/presentation/collection_vocabulary.dart';
import 'package:blindbox_app/features/collection/widgets/collection_progress_voice.dart';
import 'package:blindbox_app/features/collection/widgets/collection_series_card_content_meta.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';

/// Full-width list row for Collection List layout.
class CollectionShelfSeriesListTile extends StatelessWidget {
  const CollectionShelfSeriesListTile({
    super.key,
    required this.series,
    required this.progress,
    required this.figureStates,
    required this.onTap,
    this.onLongPress,
    this.cardContent = CollectionShelfCardContentSelection.empty,
    this.catalog,
  });

  /// Matches [AppRadii.inset] (14–16dp range).
  static const double outlineRadius = AppRadii.inset;

  /// ~12dp card padding (Shelfy [AppSpacing.md]).
  static const EdgeInsets contentPadding = EdgeInsets.symmetric(
    horizontal: AppSpacing.md,
    vertical: AppSpacing.md,
  );

  /// Vertical gap below each outlined card.
  static const double cardGap = 9;

  /// Square Series artwork (~76–80dp); pairs with [contentPadding] for ~104dp.
  static const double thumbExtent = 80;

  /// Overall content height target: 12 + 80 + 12 = 104.
  static const double minCardHeight = thumbExtent + AppSpacing.md * 2;

  /// ~6dp title → metadata (FeedRhythm collection micro-gap).
  static const double titleToMetaGap =
      FeedRhythm.collectionFilterSectionLabelToRail;

  /// ~8dp metadata → progress bar.
  static const double metaToProgressGap = AppSpacing.sm;

  /// ~6dp progress bar → progress count.
  static const double progressToCountGap =
      FeedRhythm.collectionFilterSectionLabelToRail;

  /// Artwork → text column.
  static const double artworkToTextGap = AppSpacing.md;

  final ShelfSeries series;
  final SeriesProgressCounts progress;
  final Map<String, TrackedFigure> figureStates;
  final VoidCallback onTap;
  final Future<void> Function()? onLongPress;
  final CollectionShelfCardContentSelection cardContent;
  final CatalogSeedBundle? catalog;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Same completion semantics as Grid — no List-specific progress math.
    final resolution = resolveSeriesCompletion(series, figureStates);
    final ratio = resolution.progressRatio.clamp(0.0, 1.0);
    final isComplete = resolution.isCompleted;
    final isMasterComplete = resolution.isMasterComplete;
    final lines = resolveCardContentLines(
      cardContent,
      series,
      figureStates,
      catalog: catalog,
      progress: progress,
    );
    final completion = CollectionProgressVoice.seriesStatPrimaryLine(
      series: series,
      progress: progress,
      figureStates: figureStates,
    );
    final progressLabel = isMasterComplete
        ? CollectionVocabulary.masterComplete
        : completion;

    final barColor = isComplete
        ? Color.lerp(
            scheme.primary,
            const Color(0xFFE8C547),
            isMasterComplete ? 0.72 : 0.38,
          )!.withValues(alpha: isMasterComplete ? 0.92 : 0.78)
        : scheme.primary.withValues(alpha: 0.55);

    // Same family as [CollectionBrowseCard] default border.
    final borderColor = scheme.outlineVariant.withValues(
      alpha: isDark ? 0.32 : 0.38,
    );
    final fill = scheme.surfaceContainerHighest.withValues(
      alpha: isDark ? 0.10 : 0.14,
    );
    final radius = BorderRadius.circular(outlineRadius);

    return Padding(
      padding: const EdgeInsets.only(bottom: cardGap),
      child: Material(
        color: fill,
        elevation: 0,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(width: 1, color: borderColor),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: const Key('collection_series_list_tile'),
          onTap: onTap,
          onLongPress: onLongPress == null
              ? null
              : () async {
                  await HapticFeedback.mediumImpact();
                  await onLongPress!();
                },
          borderRadius: radius,
          child: SizedBox(
            height: minCardHeight,
            child: Padding(
              padding: contentPadding,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: CollectionSeriesThumbnail(
                      series: series,
                      extent: thumbExtent,
                    ),
                  ),
                  const SizedBox(width: artworkToTextGap),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          series.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: CollectibleTypography.catalogSeriesRowTitle(
                            textTheme,
                            scheme,
                          ),
                        ),
                        if (lines.isNotEmpty) ...[
                          const SizedBox(height: titleToMetaGap),
                          CollectionSeriesCardContentMeta(
                            key: const Key('collection_series_list_meta'),
                            lines: lines,
                            horizontal: true,
                          ),
                        ],
                        SizedBox(
                          height: lines.isNotEmpty
                              ? metaToProgressGap
                              : titleToMetaGap,
                        ),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            key: const Key(
                              'collection_series_list_progress_bar',
                            ),
                            value: ratio,
                            minHeight: CollectionCardTokens.progressBarHeight,
                            backgroundColor: scheme.surfaceContainerHighest
                                .withValues(alpha: isDark ? 1 : 0.45),
                            color: barColor,
                          ),
                        ),
                        if (progressLabel.isNotEmpty) ...[
                          const SizedBox(height: progressToCountGap),
                          Text(
                            progressLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: CollectibleTypography.shelfProgressLine(
                              textTheme,
                              scheme,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Icon(
                    Symbols.chevron_right_rounded,
                    size: AppIconSizes.metadata,
                    color: scheme.onSurfaceVariant.withValues(alpha: 0.55),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
