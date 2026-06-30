import 'package:blindbox_app/core/theme/collectible_typography.dart';
import 'package:blindbox_app/features/collection/insights/domain/collector_type_stats.dart';
import 'package:blindbox_app/features/collection/presentation/collection_vocabulary.dart';
import 'package:flutter/material.dart';

class CollectorTypeTotalsRow extends StatelessWidget {
  const CollectorTypeTotalsRow({super.key, required this.stats});

  final CollectorTypeStats stats;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    // shelfProgressLine is bodyMedium w500 — matches the readable-but-quiet
    // stat pill style used across shelf surfaces.
    final meta = CollectibleTypography.shelfProgressLine(textTheme, scheme)
        .copyWith(height: 1.3);

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 12,
      runSpacing: 6,
      children: [
        _Chip(
          label: CollectionVocabulary.countLabel(
            stats.totalOwned,
            CollectionVocabulary.figures,
          ),
          style: meta,
        ),
        _Dot(scheme: scheme),
        _Chip(
          label: CollectionVocabulary.countLabel(
            stats.totalWishlist,
            CollectionVocabulary.wishlist,
          ),
          style: meta,
        ),
        _Dot(scheme: scheme),
        _Chip(
          label: CollectionVocabulary.countLabel(
            stats.trackedSeries,
            CollectionVocabulary.series,
          ),
          style: meta,
        ),
        _Dot(scheme: scheme),
        _Chip(
          label: '${stats.completionPercent}% ${CollectionVocabulary.shelfProgress}',
          style: meta,
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.style});

  final String label;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) => Text(label, style: style);
}

class _Dot extends StatelessWidget {
  const _Dot({required this.scheme});

  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 3,
      height: 3,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: scheme.primary.withValues(alpha: 0.2),
      ),
    );
  }
}
