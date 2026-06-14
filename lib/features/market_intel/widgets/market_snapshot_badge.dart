import 'package:blindbox_app/features/market_intel/domain/market_snapshot.dart';
import 'package:flutter/material.dart';

/// Inline market intelligence pill for catalog or shelf figure context.
class MarketSnapshotBadge extends StatelessWidget {
  const MarketSnapshotBadge({
    super.key,
    required this.snapshot,
  });

  final MarketSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final label = _buildLabel(snapshot);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(
          label,
          style: textTheme.labelSmall?.copyWith(
            color: scheme.onSurfaceVariant.withValues(alpha: 0.92),
            fontWeight: FontWeight.w600,
            letterSpacing: 0.02,
            height: 1.1,
          ),
        ),
      ),
    );
  }
}

String _buildLabel(MarketSnapshot snapshot) {
  final parts = <String>['~${_formatPrice(snapshot.estimatedValueUsd)}'];

  final trendLabel = _trendLabel(snapshot.trend);
  if (trendLabel != null) {
    parts.add(trendLabel);
  }

  final salesSuffix =
      snapshot.confidence == SnapshotConfidence.low ? '*' : '';
  parts.add('${snapshot.recentSalesCount} sales$salesSuffix');

  return parts.join(' · ');
}

String _formatPrice(double value) {
  return '\$${value.round()}';
}

String? _trendLabel(MarketTrend trend) {
  return switch (trend) {
    MarketTrend.rising => 'Rising',
    MarketTrend.falling => 'Falling',
    MarketTrend.stable => 'Stable',
    MarketTrend.unknown => null,
  };
}
