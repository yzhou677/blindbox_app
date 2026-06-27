import 'package:blindbox_app/core/theme/app_spacing.dart';
import 'package:blindbox_app/features/collection/insights/application/collector_type_reveal_age.dart';
import 'package:blindbox_app/features/collection/insights/presentation/collector_type_copy.dart';
import 'package:flutter/material.dart';

/// Dashboard metadata under the collector type hero — last updated + optional
/// lightweight re-reveal affordance.
class CollectorTypeRevealDashboardFooter extends StatelessWidget {
  const CollectorTypeRevealDashboardFooter({
    super.key,
    required this.revealedAt,
    required this.showRevealAgain,
    required this.onRevealAgain,
    this.now,
  });

  final DateTime revealedAt;
  final bool showRevealAgain;
  final VoidCallback onRevealAgain;
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final updatedLabel = formatCollectorTypeUpdatedLabel(
      revealedAt: revealedAt,
      now: now,
    );
    if (updatedLabel == null && !showRevealAgain) {
      return const SizedBox.shrink();
    }

    final captionStyle = textTheme.labelMedium?.copyWith(
      color: scheme.onSurfaceVariant.withValues(alpha: 0.72),
      letterSpacing: 0.08,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: AppSpacing.md),
        if (updatedLabel != null)
          Text(
            updatedLabel,
            textAlign: TextAlign.center,
            style: captionStyle,
          ),
        if (showRevealAgain) ...[
          SizedBox(height: updatedLabel != null ? 8 : 0),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onRevealAgain,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.refresh_rounded,
                      size: 15,
                      color: scheme.primary.withValues(alpha: 0.82),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      CollectorTypeCopy.revealAgain,
                      style: textTheme.labelLarge?.copyWith(
                        color: scheme.primary.withValues(alpha: 0.88),
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.06,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
