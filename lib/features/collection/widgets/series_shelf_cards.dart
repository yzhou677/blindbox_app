import 'dart:math' as math;

import 'package:blindbox_app/core/layout/feed_rhythm.dart';
import 'package:blindbox_app/core/theme/collectible_typography.dart';
import 'package:blindbox_app/core/theme/collectible_shape.dart';
import 'package:blindbox_app/core/theme/collectible_shelf_shadow.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/collection/domain/series_completion_atmosphere.dart';
import 'package:blindbox_app/features/collection/presentation/collection_series_thumbnail.dart';
import 'package:blindbox_app/features/collection/widgets/collection_progress_voice.dart';
import 'package:flutter/material.dart';

/// One series row on the collector shelf — emotional progress + subtle completion glow.
class SeriesShelfCard extends StatefulWidget {
  const SeriesShelfCard({
    super.key,
    required this.series,
    required this.progress,
    required this.figureStates,
    required this.onOpen,
    this.atmosphere,
    this.onRemove,
  });

  final ShelfSeries series;
  final SeriesProgressCounts progress;
  final Map<String, TrackedFigure> figureStates;
  final SeriesCompletionAtmosphere? atmosphere;
  final VoidCallback onOpen;
  final VoidCallback? onRemove;

  @override
  State<SeriesShelfCard> createState() => _SeriesShelfCardState();
}

class _SeriesShelfCardState extends State<SeriesShelfCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _completeGlow;
  bool _wasComplete = false;

  @override
  void initState() {
    super.initState();
    _completeGlow = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 920),
    );
    _wasComplete = _isSeriesComplete;
  }

  bool get _isSeriesComplete =>
      widget.series.figureCount > 0 &&
      widget.progress.owned >= widget.series.figureCount;

  @override
  void didUpdateWidget(SeriesShelfCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final now = _isSeriesComplete;
    if (now && !_wasComplete) {
      _completeGlow.forward(from: 0).then((_) {
        if (mounted) _completeGlow.reset();
      });
    }
    _wasComplete = now;
  }

  @override
  void dispose() {
    _completeGlow.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final extra = widget.series.notes;

    return AnimatedBuilder(
      animation: _completeGlow,
      builder: (context, child) {
        final v = Curves.easeOutCubic.transform(_completeGlow.value);
        final hump = math.sin(v * math.pi);
        final scale = 1.0 + 0.006 * hump;
        final glow = Color.lerp(
          const Color(0xFFE8C547),
          Theme.of(context).colorScheme.tertiary,
          0.35,
        )!.withValues(alpha: 0.14 * hump);

        return Transform.scale(
          scale: scale,
          alignment: Alignment.centerLeft,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: CollectibleShape.shellRadius,
              boxShadow: [
                ...CollectibleShelfShadow.productShell(
                  context,
                  accent: widget.series.shelfAccent,
                ),
                if (hump > 0.02)
                  BoxShadow(
                    color: glow,
                    blurRadius: 22 + 18 * hump,
                    spreadRadius: -6,
                    offset: const Offset(0, 8),
                  ),
              ],
            ),
            child: child,
          ),
        );
      },
      child: _SeriesMatShell(
        series: widget.series,
        accent: widget.series.shelfAccent,
        atmosphere: widget.atmosphere,
        onTap: widget.onOpen,
        trailing: widget.onRemove == null
            ? null
            : IconButton(
                icon: const Icon(Icons.delete_outline_rounded),
                tooltip: 'Remove series',
                onPressed: widget.onRemove,
              ),
        child: _SeriesMatContent(
          title: widget.series.name,
          subtitle: shelfSeriesIpLabel(widget.series),
          extraLine: extra,
          totalFigures: widget.series.figureCount,
          progress: widget.progress,
          figureStates: widget.figureStates,
          series: widget.series,
          atmosphere: widget.atmosphere,
        ),
      ),
    );
  }
}

class _SeriesMatShell extends StatelessWidget {
  const _SeriesMatShell({
    required this.series,
    required this.accent,
    required this.onTap,
    required this.child,
    this.atmosphere,
    this.trailing,
  });

  final ShelfSeries series;
  final Color accent;
  final SeriesCompletionAtmosphere? atmosphere;
  final VoidCallback onTap;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final radius = CollectibleShape.shellRadius;
    final atm = atmosphere;
    final nearComplete = atm?.nearComplete ?? false;
    final missingSecret = atm?.missingSecret ?? false;
    final sustainedComplete = atm?.complete ?? false;

    var borderColor = accent.withValues(alpha: isDark ? 0.22 : 0.38);
    if (nearComplete) {
      borderColor = Color.lerp(
        scheme.primary,
        const Color(0xFFE8C547),
        0.25,
      )!.withValues(alpha: 0.42);
    } else if (missingSecret) {
      borderColor = scheme.tertiary.withValues(alpha: 0.38);
    } else if (sustainedComplete) {
      borderColor = const Color(0xFFE8C547).withValues(alpha: 0.35);
    }

    final shadows = [
      ...CollectibleShelfShadow.productShell(context, accent: accent),
      if (sustainedComplete)
        BoxShadow(
          color: const Color(0xFFE8C547).withValues(alpha: 0.08),
          blurRadius: 16,
          offset: const Offset(0, 4),
        ),
    ];

    return Padding(
      padding: const EdgeInsets.only(bottom: FeedRhythm.listingCardVerticalGap),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: shadows,
        ),
        child: Material(
          color: scheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: radius,
            side: BorderSide(color: borderColor, width: nearComplete ? 1.2 : 1),
          ),
          clipBehavior: Clip.antiAlias,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: InkWell(
                  onTap: onTap,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CollectionSeriesThumbnail(series: series),
                        const SizedBox(width: 12),
                        Expanded(child: child),
                      ],
                    ),
                  ),
                ),
              ),
              if (trailing != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4, right: 2),
                  child: trailing!,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SeriesMatContent extends StatelessWidget {
  const _SeriesMatContent({
    required this.title,
    required this.subtitle,
    required this.totalFigures,
    required this.progress,
    required this.figureStates,
    required this.series,
    this.atmosphere,
    this.extraLine,
  });

  final String title;
  final String subtitle;
  final String? extraLine;
  final int totalFigures;
  final SeriesProgressCounts progress;
  final Map<String, TrackedFigure> figureStates;
  final ShelfSeries series;
  final SeriesCompletionAtmosphere? atmosphere;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final completion = progress.completion(totalFigures);
    final headline = CollectionProgressVoice.seriesHeadline(
      series: series,
      progress: progress,
      figureStates: figureStates,
    );
    final subline = CollectionProgressVoice.seriesSubline(
      series: series,
      progress: progress,
      figureStates: figureStates,
    );
    final isComplete = totalFigures > 0 && progress.owned >= totalFigures;
    final missingSecret = atmosphere?.missingSecret ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: CollectibleTypography.shelfSeriesTitle(textTheme, scheme),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: CollectibleTypography.seriesIpLine(textTheme, scheme),
        ),
        if (extraLine != null) ...[
          const SizedBox(height: 4),
          Text(
            extraLine!,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant.withValues(alpha: 0.65),
              height: 1.25,
            ),
          ),
        ],
        const SizedBox(height: 13),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: completion.clamp(0.0, 1.0),
            minHeight: 6,
            backgroundColor: scheme.surfaceContainerHighest.withValues(
              alpha: 0.45,
            ),
            color: isComplete
                ? Color.lerp(
                    scheme.primary,
                    const Color(0xFFE8C547),
                    0.38,
                  )!.withValues(alpha: 0.78)
                : missingSecret
                    ? scheme.tertiary.withValues(alpha: 0.55)
                    : scheme.primary.withValues(alpha: 0.48),
          ),
        ),
        const SizedBox(height: 11),
        if (headline.isNotEmpty)
          Text(
            headline,
            style: CollectibleTypography.shelfProgressLine(textTheme, scheme),
          ),
        if (subline.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            subline,
            style: CollectibleTypography.shelfProgressMeta(textTheme, scheme),
          ),
        ],
      ],
    );
  }
}
