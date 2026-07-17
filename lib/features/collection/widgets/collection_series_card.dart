import 'dart:async';

import 'package:blindbox_app/core/theme/collectible_typography.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/collection/domain/series_completion_resolution.dart';
import 'package:blindbox_app/features/collection/presentation/collection_card_tokens.dart';
import 'package:blindbox_app/features/collection/presentation/collection_series_thumbnail.dart';
import 'package:blindbox_app/features/collection/presentation/collection_vocabulary.dart';
import 'package:blindbox_app/features/collection/widgets/collection_browse_card.dart';
import 'package:blindbox_app/features/collection/widgets/collection_progress_voice.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Density for [CollectionSeriesCard] — same visual family, different footprint.
enum CollectionSeriesCardDensity {
  /// Collection shelf rails (full browse card).
  standard,

  /// Insights / dashboard rails — image-first mini presentation.
  compact,
}

/// Canonical owned-series presentation throughout the app.
///
/// Use this card for Collection rails and any future owned-series surfaces
/// (search results, favorites, See All, Continue Collecting, Insights Top Series).
/// Do not introduce parallel widgets such as `OwnedSeriesTile` / `SeriesGridCard`
/// / `CollectionCard2`.
///
/// ## Token family
///
/// Shared browse chrome comes from [AppCardTokens] via [CollectionCardTokens]
/// (width, padding, cover inset, title gaps). Progress footer spacing is
/// Collection-only. Prefer tokens over magic numbers so iPad / fold / grid
/// layouts can retarget sizes in one place.
///
/// Intentional differences vs For You: shelf media, IP meta, progress / Complete
/// / Master footer — not recommendation reason lines; management via long-press
/// action sheet (not persistent card chrome).
class CollectionSeriesCard extends StatefulWidget {
  const CollectionSeriesCard({
    super.key,
    required this.series,
    required this.progress,
    required this.figureStates,
    required this.onTap,
    this.onLongPress,
    this.density = CollectionSeriesCardDensity.standard,
    this.overlayBuilder,
  });

  final ShelfSeries series;
  final SeriesProgressCounts progress;
  final Map<String, TrackedFigure> figureStates;
  final VoidCallback onTap;

  /// Opens contextual management (edit/remove). Omit on read-only surfaces.
  final Future<void> Function()? onLongPress;
  final CollectionSeriesCardDensity density;
  final WidgetBuilder? overlayBuilder;

  /// Cross-axis extent for horizontal rails — sized by the card tokens.
  static double get railExtent =>
      railExtentFor(CollectionSeriesCardDensity.standard);

  static double railExtentFor(CollectionSeriesCardDensity density) {
    return switch (density) {
      CollectionSeriesCardDensity.standard =>
        CollectionCardTokens.minRailHeight,
      CollectionSeriesCardDensity.compact =>
        CollectionCardTokens.compactMinRailHeight,
    };
  }

  @override
  State<CollectionSeriesCard> createState() => _CollectionSeriesCardState();
}

class _CollectionSeriesCardState extends State<CollectionSeriesCard> {
  static const _pressScale = 0.98;
  static const _pressHold = Duration(milliseconds: 100);

  var _managing = false;

  bool get _compact => widget.density == CollectionSeriesCardDensity.compact;

  Future<void> _handleLongPress() async {
    final manage = widget.onLongPress;
    if (manage == null || _managing) return;

    setState(() => _managing = true);
    // Fire-and-forget: platform channel must not gate the press chrome timing.
    unawaited(HapticFeedback.mediumImpact());
    await Future<void>.delayed(_pressHold);
    if (!mounted) return;

    try {
      final sheet = manage();
      // Release press chrome as the action sheet rises.
      if (mounted) setState(() => _managing = false);
      await sheet;
    } finally {
      if (mounted && _managing) setState(() => _managing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final series = widget.series;
    final progress = widget.progress;
    final figureStates = widget.figureStates;
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

    final width = _compact
        ? CollectionCardTokens.compactWidth
        : CollectionCardTokens.width;
    final height = _compact
        ? CollectionCardTokens.compactMinRailHeight
        : CollectionCardTokens.minRailHeight;
    final padding = _compact
        ? CollectionCardTokens.compactPadding
        : CollectionCardTokens.padding;
    final coverExtent = _compact
        ? CollectionCardTokens.compactCoverExtent
        : CollectionCardTokens.coverExtent;
    final imageToTitleGap = _compact
        ? CollectionCardTokens.compactImageToTitleGap
        : CollectionCardTokens.imageToTitleGap;
    final titleToMetaGap = _compact
        ? CollectionCardTokens.compactTitleToMetaGap
        : CollectionCardTokens.titleToMetaGap;
    final metaToProgressGap = _compact
        ? CollectionCardTokens.compactMetaToProgressGap
        : CollectionCardTokens.metaToProgressGap;

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

    return AnimatedScale(
      scale: _managing ? _pressScale : 1,
      duration: _pressHold,
      curve: Curves.easeOutCubic,
      child: CollectionBrowseCard(
        key: const Key('collection_series_card'),
        title: series.name,
        subtitle: meta,
        titleMaxLines: _compact ? 1 : 2,
        titleStyle: CollectibleTypography.catalogSeriesRowTitle(
          textTheme,
          scheme,
        ).copyWith(
          fontSize: _compact ? 13 : null,
          height: _compact ? 1.2 : null,
        ),
        subtitleStyle: CollectibleTypography.seriesIpLine(
          textTheme,
          scheme,
        ).copyWith(
          fontSize: _compact ? 11 : null,
        ),
        image: CollectionSeriesThumbnail(
          series: series,
          extent: coverExtent,
        ),
        footer: isComplete
            ? _CompletedFooter(
                isMasterComplete: isMasterComplete,
                textTheme: textTheme,
                scheme: scheme,
                barColor: barColor,
                isDark: isDark,
                compact: _compact,
              )
            : _InProgressFooter(
                ratio: ratio,
                label: progressLabel,
                textTheme: textTheme,
                scheme: scheme,
                barColor: barColor,
                isDark: isDark,
                compact: _compact,
              ),
        onTap: widget.onTap,
        onLongPress: widget.onLongPress == null ? null : _handleLongPress,
        overlayBuilder: widget.overlayBuilder,
        width: width,
        height: height,
        padding: padding,
        imageExtent: coverExtent,
        imageToTitleGap: imageToTitleGap,
        titleToMetaGap: titleToMetaGap,
        metaToFooterGap: metaToProgressGap,
        borderColor: borderColor,
        showPressedOverlay: _managing,
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
    required this.compact,
  });

  final double ratio;
  final String label;
  final TextTheme textTheme;
  final ColorScheme scheme;
  final Color barColor;
  final bool isDark;
  final bool compact;

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
            style: CollectibleTypography.shelfProgressLine(textTheme, scheme)
                .copyWith(fontSize: compact ? 11 : null),
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
    required this.compact,
  });

  final bool isMasterComplete;
  final TextTheme textTheme;
  final ColorScheme scheme;
  final Color barColor;
  final bool isDark;
  final bool compact;

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
          style: style.copyWith(fontSize: compact ? 11 : null),
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
