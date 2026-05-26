import 'package:blindbox_app/core/theme/collectible_tokens.dart';
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
    final tokens = CollectibleTokens.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Top series',
          style: textTheme.labelMedium?.copyWith(
            color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        for (final name in seriesNames)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              name,
              style: tokens.supportiveBody(textTheme, scheme),
            ),
          ),
      ],
    );
  }
}
