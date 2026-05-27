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
        for (final name in seriesNames)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: Text(
              name,
              style: CollectibleTypography.shelfProgressLine(textTheme, scheme)
                  .copyWith(height: 1.35),
            ),
          ),
      ],
    );
  }
}
