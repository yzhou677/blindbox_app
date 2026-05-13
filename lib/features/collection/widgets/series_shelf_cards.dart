import 'dart:math' as math;

import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
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
    this.onRemove,
  });

  final SeriesDefinition series;
  final SeriesProgressCounts progress;
  final Map<String, TrackedFigure> figureStates;
  final VoidCallback onOpen;
  final VoidCallback? onRemove;

  @override
  State<SeriesShelfCard> createState() => _SeriesShelfCardState();
}

class _SeriesShelfCardState extends State<SeriesShelfCard> with SingleTickerProviderStateMixin {
  late AnimationController _completeGlow;
  bool _wasComplete = false;

  @override
  void initState() {
    super.initState();
    _completeGlow = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 920),
    );
    _wasComplete = _isLineComplete;
  }

  bool get _isLineComplete =>
      widget.series.figureCount > 0 && widget.progress.owned >= widget.series.figureCount;

  @override
  void didUpdateWidget(SeriesShelfCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final now = _isLineComplete;
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
    final chaseCount = widget.series.figures.where((f) => f.isSecret).length;
    final chaseLabel = chaseCount > 0 ? '$chaseCount chase in set' : null;
    final extra = widget.series.notes ?? chaseLabel;

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
              borderRadius: BorderRadius.circular(24),
              boxShadow: hump > 0.02
                  ? [
                      BoxShadow(
                        color: glow,
                        blurRadius: 22 + 18 * hump,
                        spreadRadius: -6,
                        offset: const Offset(0, 8),
                      ),
                    ]
                  : const [],
            ),
            child: child,
          ),
        );
      },
      child: _SeriesMatShell(
        accent: widget.series.shelfAccent,
        onTap: widget.onOpen,
        trailing: widget.onRemove == null
            ? null
            : IconButton(
                icon: const Icon(Icons.delete_outline_rounded),
                tooltip: 'Remove line',
                onPressed: widget.onRemove,
              ),
        child: _SeriesMatContent(
          title: widget.series.name,
          subtitle: '${widget.series.ipName} · ${widget.series.brand}',
          extraLine: extra,
          totalFigures: widget.series.figureCount,
          progress: widget.progress,
          figureStates: widget.figureStates,
          series: widget.series,
        ),
      ),
    );
  }
}

class _SeriesMatShell extends StatelessWidget {
  const _SeriesMatShell({
    required this.accent,
    required this.onTap,
    required this.child,
    this.trailing,
  });

  final Color accent;
  final VoidCallback onTap;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final radius = BorderRadius.circular(22);

    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: [
            BoxShadow(
              color: Color.lerp(scheme.shadow, accent, 0.08)!
                  .withValues(alpha: isDark ? 0.32 : 0.08),
              blurRadius: 22,
              offset: const Offset(0, 11),
              spreadRadius: -4,
            ),
          ],
        ),
        child: Material(
          color: scheme.surfaceContainerLow,
          shape: RoundedRectangleBorder(
            borderRadius: radius,
            side: BorderSide(
              color: accent.withValues(alpha: isDark ? 0.22 : 0.38),
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: InkWell(
                  onTap: onTap,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 15, 12, 15),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 4,
                          height: 54,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(999),
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                accent.withValues(alpha: 0.95),
                                Color.lerp(accent, scheme.primary, 0.12)!.withValues(alpha: 0.45),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
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
    this.extraLine,
  });

  final String title;
  final String subtitle;
  final String? extraLine;
  final int totalFigures;
  final SeriesProgressCounts progress;
  final Map<String, TrackedFigure> figureStates;
  final SeriesDefinition series;

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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: -0.14,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: textTheme.labelLarge?.copyWith(
            color: scheme.onSurfaceVariant.withValues(alpha: 0.78),
            fontWeight: FontWeight.w500,
            letterSpacing: 0.06,
          ),
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
            backgroundColor: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
            color: isComplete
                ? Color.lerp(scheme.tertiary, const Color(0xFFE8C547), 0.35)!.withValues(alpha: 0.75)
                : scheme.primary.withValues(alpha: 0.48),
          ),
        ),
        const SizedBox(height: 11),
        Text(
          headline,
          style: textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.12,
            height: 1.25,
            color: isComplete
                ? Color.lerp(scheme.onTertiaryContainer, scheme.onSurface, 0.15)
                : scheme.onSurface.withValues(alpha: 0.92),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subline,
          style: textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant.withValues(alpha: 0.78),
            height: 1.35,
          ),
        ),
      ],
    );
  }
}
