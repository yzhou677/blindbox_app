import 'dart:math' as math;

import 'package:blindbox_app/features/collection/application/collection_notifier.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/collection/widgets/figure_capsule_card.dart';
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

    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final progress = progressForSeries(series, snap.figureStates);
    final isComplete = series.figureCount > 0 && progress.owned >= series.figureCount;
    final secrets = series.figures.where((f) => f.isSecret).toList();
    final chasesHome =
        secrets.isNotEmpty && secrets.every((f) => snap.trackedOrDefault(f.id).owned);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: scheme.outlineVariant.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              series.ipName,
              style: textTheme.labelLarge?.copyWith(
                color: scheme.onSurfaceVariant.withValues(alpha: 0.82),
                fontWeight: FontWeight.w600,
                letterSpacing: 0.12,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              series.name,
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
                letterSpacing: -0.22,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Tap a figure: want list → collected → open slot',
              style: textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant.withValues(alpha: 0.86),
                height: 1.35,
              ),
            ),
            if (isComplete) ...[
              const SizedBox(height: 14),
              _SeriesCompleteBanner(
                chasesHome: chasesHome && secrets.isNotEmpty,
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              height: math.min(MediaQuery.sizeOf(context).height * 0.52, 440),
              child: SingleChildScrollView(
                child: Wrap(
                  spacing: 12,
                  runSpacing: 14,
                  alignment: WrapAlignment.start,
                  children: [
                    for (final f in series.figures)
                      FigureCapsuleCard(
                        figure: f,
                        tracked: snap.trackedOrDefault(f.id),
                        onTap: () => notifier.cycleFigure(f.id),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
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
            Color.lerp(scheme.primaryContainer, const Color(0xFFFFF6E8), isDark ? 0.15 : 0.45)!
                .withValues(alpha: isDark ? 0.5 : 0.72),
            scheme.surfaceContainerHighest.withValues(alpha: 0.35),
          ],
        ),
        border: Border.all(
          color: Color.lerp(scheme.primary, const Color(0xFFE8C547), 0.3)!.withValues(alpha: 0.45),
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
                    chasesHome ? 'Whole series — chase home' : 'This series feels complete',
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.1,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    chasesHome
                        ? 'A rare, quiet moment for the shelf.'
                        : 'Every figure has found its place here.',
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
