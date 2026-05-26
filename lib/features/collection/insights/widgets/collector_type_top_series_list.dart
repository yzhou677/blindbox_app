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
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              name,
              style: textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant.withValues(alpha: 0.86),
                fontWeight: FontWeight.w500,
                height: 1.35,
              ),
            ),
          ),
      ],
    );
  }
}
