import 'package:blindbox_app/features/collection/domain/series_completion_resolution.dart';
import 'package:blindbox_app/features/collection/presentation/collection_vocabulary.dart';
import 'package:flutter/material.dart';

/// Shelf stat-line completion tier — drives calm, at-a-glance atmosphere.
enum SeriesCompletionStatLevel {
  inProgress,
  seriesComplete,
  masterComplete,
}

SeriesCompletionStatLevel seriesCompletionStatLevel(
  SeriesCompletionResolution resolution,
) {
  if (resolution.isMasterComplete) return SeriesCompletionStatLevel.masterComplete;
  if (resolution.isCompleted) return SeriesCompletionStatLevel.seriesComplete;
  return SeriesCompletionStatLevel.inProgress;
}

/// Stat primary line with tier-appropriate atmosphere (no effect / blue glow / static master).
class SeriesCompletionStatSlot extends StatelessWidget {
  const SeriesCompletionStatSlot({
    super.key,
    required this.level,
    required this.statPrimary,
    required this.masterTextStyle,
    required this.completeTextStyle,
    required this.progressTextStyle,
    required this.colorScheme,
  });

  final SeriesCompletionStatLevel level;
  final String statPrimary;
  final TextStyle masterTextStyle;
  final TextStyle completeTextStyle;
  final TextStyle progressTextStyle;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return switch (level) {
      SeriesCompletionStatLevel.masterComplete => Semantics(
          label: CollectionVocabulary.masterComplete,
          child: ExcludeSemantics(
            child: Text(
              '👑 ${CollectionVocabulary.masterComplete}',
              key: const Key('master_complete_stat_line'),
              style: masterTextStyle,
            ),
          ),
        ),
      SeriesCompletionStatLevel.seriesComplete => SeriesCompleteStatGlow(
          colorScheme: colorScheme,
          child: Text(statPrimary, style: completeTextStyle),
        ),
      SeriesCompletionStatLevel.inProgress => Text(
          statPrimary,
          style: progressTextStyle,
        ),
    };
  }
}

/// Sustained soft blue glow behind a series-complete stat — static, never animated.
class SeriesCompleteStatGlow extends StatelessWidget {
  const SeriesCompleteStatGlow({
    super.key,
    required this.child,
    required this.colorScheme,
  });

  final Widget child;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    final wash = colorScheme.primary.withValues(alpha: 0.06);
    final halo = colorScheme.primary.withValues(alpha: 0.11);

    return RepaintBoundary(
      child: DecoratedBox(
        key: const Key('series_complete_stat_glow'),
        decoration: BoxDecoration(
          color: wash,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: halo,
              blurRadius: 16,
              spreadRadius: -5,
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          child: child,
        ),
      ),
    );
  }
}
