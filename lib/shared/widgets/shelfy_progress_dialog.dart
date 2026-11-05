import 'package:flutter/material.dart';

/// Compact indeterminate progress chip used by share-card and shelf-backup.
class ShelfyProgressDialogContent extends StatelessWidget {
  const ShelfyProgressDialogContent({
    super.key,
    required this.label,
  });

  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Center(
      child: Material(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: scheme.primary.withValues(alpha: 0.72),
                ),
              ),
              const SizedBox(width: 14),
              Flexible(
                child: Text(
                  label,
                  style: textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurface.withValues(alpha: 0.78),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
