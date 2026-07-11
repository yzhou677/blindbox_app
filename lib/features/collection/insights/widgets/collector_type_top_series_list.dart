import 'package:blindbox_app/core/theme/app_spacing.dart';
import 'package:blindbox_app/core/theme/collectible_typography.dart';
import 'package:flutter/material.dart';

class CollectorTypeTopSeriesList extends StatelessWidget {
  const CollectorTypeTopSeriesList({
    super.key,
    required this.seriesNames,
  });

  final List<String> seriesNames;

  @override
  Widget build(BuildContext context) {
    if (seriesNames.isEmpty) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < seriesNames.length; i++) ...[
          if (i > 0) const SizedBox(height: AppSpacing.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 22,
                child: Text(
                  '${i + 1}',
                  style: textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: scheme.primary.withValues(alpha: 0.55),
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  seriesNames[i],
                  style: CollectibleTypography.shelfProgressLine(
                    textTheme,
                    scheme,
                  ).copyWith(height: 1.35),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
