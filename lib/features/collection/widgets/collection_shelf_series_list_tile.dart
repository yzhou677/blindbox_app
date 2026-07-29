import 'package:blindbox_app/core/theme/app_radii.dart';
import 'package:blindbox_app/core/theme/collectible_typography.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/collection/domain/series_completion_resolution.dart';
import 'package:blindbox_app/features/collection/presentation/collection_series_thumbnail.dart';
import 'package:blindbox_app/features/collection/presentation/collection_vocabulary.dart';
import 'package:blindbox_app/features/collection/widgets/collection_progress_voice.dart';
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
  });

  /// Matches [AppRadii.inset] (14–16dp range).
  static const double outlineRadius = AppRadii.inset;

  static const EdgeInsets contentPadding = EdgeInsets.all(11);

  /// Vertical gap below each outlined card.
  static const double cardGap = 9;

  static const double thumbExtent = 64;

  final ShelfSeries series;
  final SeriesProgressCounts progress;
  final Map<String, TrackedFigure> figureStates;
  final VoidCallback onTap;
  final Future<void> Function()? onLongPress;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final resolution = resolveSeriesCompletion(series, figureStates);
    final ip = shelfSeriesIpLabel(series).trim();
    final brand = series.brand.trim();
    final contextLine = [
      if (ip.isNotEmpty) ip,
      if (brand.isNotEmpty && brand.toLowerCase() != ip.toLowerCase()) brand,
    ].join(' · ');
    final completion = CollectionProgressVoice.seriesStatPrimaryLine(
      series: series,
      progress: progress,
      figureStates: figureStates,
    );

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
          child: Padding(
            padding: contentPadding,
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: CollectionSeriesThumbnail(
                    series: series,
                    extent: thumbExtent,
                  ),
                ),
                const SizedBox(width: 14),
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
                      if (contextLine.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          contextLine,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: CollectibleTypography.seriesIpLine(
                            textTheme,
                            scheme,
                          ),
                        ),
                      ],
                      if (completion.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          resolution.isMasterComplete
                              ? CollectionVocabulary.masterComplete
                              : completion,
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
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.55),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
