import 'package:flutter/material.dart';

/// One calm relationship hint — italic, subdued, never a carousel.
class CollectibleRelationshipLine extends StatelessWidget {
  const CollectibleRelationshipLine({
    super.key,
    required this.text,
    this.padding = EdgeInsets.zero,
  });

  final String text;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    if (text.trim().isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: padding,
      child: Text(
        text,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: textTheme.bodySmall?.copyWith(
          color: scheme.onSurfaceVariant.withValues(alpha: 0.72),
          height: 1.3,
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }
}
