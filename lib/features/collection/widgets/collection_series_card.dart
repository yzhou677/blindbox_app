import 'package:blindbox_app/core/layout/feed_rhythm.dart';
import 'package:blindbox_app/core/theme/app_radii.dart';
import 'package:blindbox_app/core/theme/collectible_elevation.dart';
import 'package:blindbox_app/core/theme/collectible_typography.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/collection/domain/series_completion_resolution.dart';
import 'package:blindbox_app/features/collection/presentation/collection_series_thumbnail.dart';
import 'package:blindbox_app/features/collection/presentation/collection_vocabulary.dart';
import 'package:blindbox_app/features/collection/widgets/collection_progress_voice.dart';
import 'package:flutter/material.dart';

/// Primary browse card for an owned [ShelfSeries] on Collection rails.
///
/// ## Token parity with For You (`ForYouSeriesCard`)
///
/// **Shared (same design family — reuse tokens, not the widget):**
/// - Card width: [FeedRhythm.collectionShelfRailCardWidth] (= 168, For You width)
/// - Outer radius: [AppRadii.cardRadius]
/// - Image mat radius: [AppRadii.matRadius]
/// - Elevation: [CollectibleElevation.softCard]
/// - Fill: [ColorScheme.surface]
/// - Hairline: [ColorScheme.outlineVariant] @ 0.32 dark / 0.38 light
/// - Inner padding: `12, 12, 12, 14`
/// - Image → title gap: `10`
/// - Title → meta gap: `4`
/// - Title style: [CollectibleTypography.catalogSeriesRowTitle]
/// - Square cover footprint: `width - 24`
///
/// **Intentional differences (ownership / progress):**
/// - Media: [CollectionSeriesThumbnail] (shelf cover + catalog `imageKey`)
/// - Meta: IP (fallback brand) via [CollectibleTypography.seriesIpLine]
///   — not For You recommendation reason lines
/// - Footer: progress bar + `N / D`, or Complete / Master Complete
/// - Rail height: [FeedRhythm.collectionShelfRailHeight] (taller than For You’s
///   [FeedRhythm.marketChasersRailHeight] to fit progress)
/// - No Remove / Edit chrome — management stays in the figures sheet
class CollectionSeriesCard extends StatelessWidget {
  const CollectionSeriesCard({
    super.key,
    required this.series,
    required this.progress,
    required this.figureStates,
    required this.onTap,
  });

  final ShelfSeries series;
  final SeriesProgressCounts progress;
  final Map<String, TrackedFigure> figureStates;
  final VoidCallback onTap;

  static const EdgeInsets _padding = EdgeInsets.fromLTRB(12, 12, 12, 14);
  static const double _imageToTitleGap = 10;
  static const double _titleToMetaGap = 4;
  static const double _metaToProgressGap = 10;
  static const double _progressBarHeight = 5;
  static const double _progressToLabelGap = 6;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final resolution = resolveSeriesCompletion(series, figureStates);
    final isComplete = resolution.isCompleted;
    final isMasterComplete = resolution.isMasterComplete;
    final ratio = resolution.progressRatio.clamp(0.0, 1.0);
    final ip = shelfSeriesIpLabel(series).trim();
    final meta = ip.isNotEmpty
        ? ip
        : (series.brand.trim().isNotEmpty ? series.brand.trim() : '');
    final progressLabel = CollectionProgressVoice.seriesStatPrimaryLine(
      series: series,
      progress: progress,
      figureStates: figureStates,
    );
    final thumbExtent = FeedRhythm.collectionShelfRailCardWidth - 24;

    final borderColor = isMasterComplete
        ? const Color(0xFFE8C547).withValues(alpha: isDark ? 0.42 : 0.4)
        : isComplete
            ? Color.lerp(
                scheme.outlineVariant,
                const Color(0xFFE8C547),
                0.35,
              )!.withValues(alpha: isDark ? 0.4 : 0.45)
            : scheme.outlineVariant.withValues(alpha: isDark ? 0.32 : 0.38);

    final barColor = isComplete
        ? Color.lerp(
            scheme.primary,
            const Color(0xFFE8C547),
            isMasterComplete ? 0.72 : 0.38,
          )!.withValues(alpha: isMasterComplete ? 0.92 : 0.78)
        : scheme.primary.withValues(alpha: 0.55);

    return SizedBox(
      key: const Key('collection_series_card'),
      width: FeedRhythm.collectionShelfRailCardWidth,
      height: FeedRhythm.collectionShelfRailHeight,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: AppRadii.cardRadius,
          boxShadow: CollectibleElevation.softCard(context),
        ),
        child: Material(
          color: scheme.surface,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: AppRadii.cardRadius,
            side: BorderSide(color: borderColor),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: _padding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: Center(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final side = constraints.biggest.shortestSide
                              .clamp(0.0, thumbExtent);
                          return ClipRRect(
                            borderRadius: AppRadii.matRadius,
                            child: CollectionSeriesThumbnail(
                              series: series,
                              extent: side,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: _imageToTitleGap),
                  Text(
                    series.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: CollectibleTypography.catalogSeriesRowTitle(
                      textTheme,
                      scheme,
                    ),
                  ),
                  if (meta.isNotEmpty) ...[
                    const SizedBox(height: _titleToMetaGap),
                    Text(
                      meta,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: CollectibleTypography.seriesIpLine(
                        textTheme,
                        scheme,
                      ),
                    ),
                  ],
                  const SizedBox(height: _metaToProgressGap),
                  if (isComplete)
                    _CompletedFooter(
                      isMasterComplete: isMasterComplete,
                      textTheme: textTheme,
                      scheme: scheme,
                      barColor: barColor,
                      isDark: isDark,
                    )
                  else
                    _InProgressFooter(
                      ratio: ratio,
                      label: progressLabel,
                      textTheme: textTheme,
                      scheme: scheme,
                      barColor: barColor,
                      isDark: isDark,
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

class _InProgressFooter extends StatelessWidget {
  const _InProgressFooter({
    required this.ratio,
    required this.label,
    required this.textTheme,
    required this.scheme,
    required this.barColor,
    required this.isDark,
  });

  final double ratio;
  final String label;
  final TextTheme textTheme;
  final ColorScheme scheme;
  final Color barColor;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: CollectionSeriesCard._progressBarHeight,
            backgroundColor: scheme.surfaceContainerHighest.withValues(
              alpha: isDark ? 1 : 0.45,
            ),
            color: barColor,
          ),
        ),
        if (label.isNotEmpty) ...[
          const SizedBox(height: CollectionSeriesCard._progressToLabelGap),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: CollectibleTypography.shelfProgressLine(textTheme, scheme),
          ),
        ],
      ],
    );
  }
}

class _CompletedFooter extends StatelessWidget {
  const _CompletedFooter({
    required this.isMasterComplete,
    required this.textTheme,
    required this.scheme,
    required this.barColor,
    required this.isDark,
  });

  final bool isMasterComplete;
  final TextTheme textTheme;
  final ColorScheme scheme;
  final Color barColor;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final label = isMasterComplete
        ? '👑 ${CollectionVocabulary.masterComplete}'
        : CollectionVocabulary.seriesCompleteBadge;
    final style = isMasterComplete
        ? CollectibleTypography.shelfMasterCompleteStatLine(textTheme, scheme)
        : CollectibleTypography.shelfCompleteStatLine(textTheme, scheme);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: style,
        ),
        const SizedBox(height: CollectionSeriesCard._progressToLabelGap),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: 1,
            minHeight: CollectionSeriesCard._progressBarHeight,
            backgroundColor: scheme.surfaceContainerHighest.withValues(
              alpha: isDark ? 1 : 0.45,
            ),
            color: barColor,
          ),
        ),
      ],
    );
  }
}
