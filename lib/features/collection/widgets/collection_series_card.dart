import 'package:blindbox_app/core/theme/app_radii.dart';
import 'package:blindbox_app/core/theme/collectible_elevation.dart';
import 'package:blindbox_app/core/theme/collectible_typography.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/collection/domain/series_completion_resolution.dart';
import 'package:blindbox_app/features/collection/presentation/collection_card_tokens.dart';
import 'package:blindbox_app/features/collection/presentation/collection_series_thumbnail.dart';
import 'package:blindbox_app/features/collection/presentation/collection_vocabulary.dart';
import 'package:blindbox_app/features/collection/widgets/collection_progress_voice.dart';
import 'package:flutter/material.dart';

/// Canonical owned-series presentation throughout the app.
///
/// Use this card for Collection rails and any future owned-series surfaces
/// (search results, favorites, See All, Continue Collecting). Do not introduce
/// parallel widgets such as `OwnedSeriesTile` / `SeriesGridCard` / `CollectionCard2`.
///
/// ## Token family
///
/// Shared browse chrome comes from [AppCardTokens] via [CollectionCardTokens]
/// (width, padding, cover inset, title gaps). Progress footer spacing is
/// Collection-only. Prefer tokens over magic numbers so iPad / fold / grid
/// layouts can retarget sizes in one place.
///
/// Intentional differences vs For You: shelf media, IP meta, progress / Complete
/// / Master footer — not recommendation reason lines; no management chrome.
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

  /// Cross-axis extent for horizontal rails — sized by the card tokens.
  static double get railExtent => CollectionCardTokens.minRailHeight;

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
    final coverExtent = CollectionCardTokens.coverExtent;

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
      width: CollectionCardTokens.width,
      height: CollectionCardTokens.minRailHeight,
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
              padding: CollectionCardTokens.padding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: ClipRRect(
                      borderRadius: AppRadii.matRadius,
                      child: CollectionSeriesThumbnail(
                        series: series,
                        extent: coverExtent,
                      ),
                    ),
                  ),
                  const SizedBox(height: CollectionCardTokens.imageToTitleGap),
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
                    const SizedBox(height: CollectionCardTokens.titleToMetaGap),
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
                  const Spacer(),
                  const SizedBox(height: CollectionCardTokens.metaToProgressGap),
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
            minHeight: CollectionCardTokens.progressBarHeight,
            backgroundColor: scheme.surfaceContainerHighest.withValues(
              alpha: isDark ? 1 : 0.45,
            ),
            color: barColor,
          ),
        ),
        if (label.isNotEmpty) ...[
          const SizedBox(height: CollectionCardTokens.progressToLabelGap),
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
        const SizedBox(height: CollectionCardTokens.progressToLabelGap),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: 1,
            minHeight: CollectionCardTokens.progressBarHeight,
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
