import 'package:blindbox_app/core/theme/app_radii.dart';
import 'package:blindbox_app/features/collection/presentation/collection_series_shelf_cta_presentation.dart';
import 'package:flutter/material.dart';

/// Shared trailing chip for catalog rows — label/icon/tint from [presentation].
class CollectionSeriesShelfCtaTrailing extends StatelessWidget {
  const CollectionSeriesShelfCtaTrailing({
    super.key,
    required this.presentation,
    this.onPressed,
  });

  final CollectionSeriesShelfCtaPresentation presentation;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final effectiveOnPressed = presentation.enabled ? onPressed : null;

    final fg = presentation.usePrimaryTint
        ? scheme.primary
        : scheme.onSurfaceVariant.withValues(alpha: 0.82);
    final bg = presentation.usePrimaryTint
        ? scheme.primary.withValues(alpha: 0.14)
        : scheme.surfaceContainerHighest.withValues(alpha: 0.7);

    return Semantics(
      button: true,
      enabled: presentation.enabled,
      label: presentation.semanticsLabel,
      child: Material(
        color: bg,
        borderRadius: AppRadii.insetRadius,
        child: InkWell(
          onTap: effectiveOnPressed,
          borderRadius: AppRadii.insetRadius,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (presentation.label.isNotEmpty) ...[
                  Text(
                    presentation.label,
                    style: textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: fg,
                    ),
                  ),
                  const SizedBox(width: 4),
                ],
                Icon(presentation.icon, size: 20, color: fg),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
