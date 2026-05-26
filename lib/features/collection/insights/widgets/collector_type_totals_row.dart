import 'package:blindbox_app/features/collection/insights/domain/collector_type_stats.dart';
import 'package:flutter/material.dart';

class CollectorTypeTotalsRow extends StatelessWidget {
  const CollectorTypeTotalsRow({super.key, required this.stats});

  final CollectorTypeStats stats;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final meta = textTheme.bodySmall?.copyWith(
      color: scheme.onSurfaceVariant.withValues(alpha: 0.72),
      height: 1.2,
    );

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 4,
      children: [
        _Chip(label: '${stats.totalOwned} owned', style: meta),
        _Dot(scheme: scheme),
        _Chip(label: '${stats.totalWishlist} wishlist', style: meta),
        _Dot(scheme: scheme),
        _Chip(label: '${stats.trackedSeries} series', style: meta),
        _Dot(scheme: scheme),
        _Chip(label: '${stats.completionPercent}% complete', style: meta),
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
