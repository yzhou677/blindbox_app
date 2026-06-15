import 'package:blindbox_app/features/market_intel/domain/market_snapshot.dart';
import 'package:blindbox_app/features/market_intel/widgets/market_snapshot_format.dart';
import 'package:flutter/material.dart';

/// Secondary market details inside the expanded Discover accordion — range and freshness.
class MarketSnapshotDiscoverExpandPanel extends StatelessWidget {
  const MarketSnapshotDiscoverExpandPanel({
    super.key,
    required this.snapshot,
    required this.foregroundColor,
  });

  final MarketSnapshot snapshot;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final rangeValue = formatMarketSnapshotDiscoverPriceRangeValue(snapshot);
    final updatedLine = formatMarketSnapshotUpdatedLine(snapshot.computedAt);

    final labelStyle = textTheme.labelSmall?.copyWith(
      color: foregroundColor.withValues(alpha: 0.58),
      fontWeight: FontWeight.w600,
      letterSpacing: 0.03,
    );
    final metaStyle = textTheme.bodySmall?.copyWith(
      color: foregroundColor.withValues(alpha: 0.76),
      height: 1.35,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (rangeValue != null) ...[
          const SizedBox(height: 12),
          Text('Range', textAlign: TextAlign.center, style: labelStyle),
          const SizedBox(height: 4),
          Text(rangeValue, textAlign: TextAlign.center, style: metaStyle),
        ],
        const SizedBox(height: 10),
        Text(updatedLine, textAlign: TextAlign.center, style: metaStyle),
      ],
    );
  }
}
