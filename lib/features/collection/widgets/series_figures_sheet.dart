import 'dart:math' as math;

import 'package:blindbox_app/features/collection/application/collection_notifier.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/collection/widgets/figure_capsule_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

SeriesDefinition? _findSeries(CollectionSnapshot snap, String seriesId) {
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
              '${series.brand} · tap a figure: wish → own → clear',
              style: textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant.withValues(alpha: 0.86),
                height: 1.35,
              ),
            ),
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
