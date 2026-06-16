import 'package:blindbox_app/features/market_intel/domain/market_snapshot.dart';
import 'package:blindbox_app/features/market_intel/widgets/market_snapshot_format.dart';
import 'package:flutter/material.dart';

/// Compact market intelligence panel for catalog or shelf figure context.
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

    final salesLine = formatMarketSnapshotSalesLine(snapshot);
    final rangeLine = formatMarketSnapshotPriceRangeLine(snapshot);
    final updatedLine = formatMarketSnapshotUpdatedLine(snapshot.computedAt);

    final metaStyle = textTheme.bodySmall?.copyWith(
      color: scheme.onSurfaceVariant.withValues(alpha: 0.88),
      height: 1.25,
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(12),
        border: snapshot.isSeriesEstimate
            ? Border.all(
                color: scheme.tertiary.withValues(alpha: 0.28),
              )
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              snapshot.isSeriesEstimate
                  ? snapshotTierBBadgeHeadingLabel(snapshot)
                  : 'Market Value',
              style: textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant.withValues(alpha: 0.78),
                fontWeight: FontWeight.w600,
                letterSpacing: 0.04,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              formatMarketSnapshotValue(snapshot.estimatedValueUsd),
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                height: 1.05,
                letterSpacing: -0.02,
              ),
            ),
            if (snapshot.isSeriesEstimate) ...[
              const SizedBox(height: 6),
              _SeriesEstimateChip(
                scheme: scheme,
                textTheme: textTheme,
                label: snapshotTierBEstimateChipLabel(snapshot),
              ),
            ],
            if (salesLine != null) ...[
              SizedBox(height: snapshot.isSeriesEstimate ? 4 : 6),
              Text(salesLine, style: metaStyle),
            ],
            if (rangeLine != null) ...[
              const SizedBox(height: 2),
              Text(rangeLine, style: metaStyle),
            ],
            const SizedBox(height: 2),
            Text(updatedLine, style: metaStyle),
          ],
        ),
      ),
    );
  }
}

class _SeriesEstimateChip extends StatelessWidget {
  const _SeriesEstimateChip({
    required this.scheme,
    required this.textTheme,
    required this.label,
  });

  final ColorScheme scheme;
  final TextTheme textTheme;
  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.tertiaryContainer.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(
          '≈ $label',
          style: textTheme.labelSmall?.copyWith(
            color: scheme.onTertiaryContainer.withValues(alpha: 0.95),
            fontWeight: FontWeight.w600,
            letterSpacing: 0.02,
            height: 1.1,
          ),
        ),
      ),
    );
  }
}
