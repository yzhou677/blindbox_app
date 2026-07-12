import 'package:blindbox_app/core/theme/app_radii.dart';
import 'package:blindbox_app/core/theme/app_spacing.dart';
import 'package:blindbox_app/core/theme/app_typography.dart';
import 'package:blindbox_app/core/theme/collectible_elevation.dart';
import 'package:blindbox_app/core/theme/collectible_typography.dart';
import 'package:blindbox_app/features/collection/insights/domain/collector_type_identity.dart';
import 'package:blindbox_app/features/collection/insights/widgets/collector_type_glyph.dart';
import 'package:blindbox_app/features/collection/insights/widgets/collector_type_reveal_dashboard_footer.dart';
import 'package:flutter/material.dart';

/// Hero identity surface for the revealed collector type — visual anchor of Insights.
class CollectorTypeResultCard extends StatelessWidget {
  const CollectorTypeResultCard({
    super.key,
    required this.identity,
    this.becauseLine,
    this.helperLine,
    this.showRevealAgain = false,
    this.onRevealAgain,
    this.updatedAtNow,
  });

  final CollectorTypeIdentity identity;

  /// Causal “Because…” from [CollectorTypeReasonKey] — primary line under title.
  final String? becauseLine;
  final String? helperLine;
  final bool showRevealAgain;
  final VoidCallback? onRevealAgain;
  final DateTime? updatedAtNow;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final archetype = identity.archetype;
    final accent = archetype.accentFor(Theme.of(context).brightness);
    final because = becauseLine?.trim();
    final hasBecause = because != null && because.isNotEmpty;
    final hasHelper = helperLine != null && helperLine!.trim().isNotEmpty;

    return RepaintBoundary(
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: AppRadii.cardRadius,
          boxShadow: CollectibleElevation.softCard(context),
        ),
        child: Material(
          color: Color.lerp(
            scheme.surface,
            accent,
            isDark ? 0.12 : 0.08,
          ),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: AppRadii.cardRadius,
            side: BorderSide(color: accent.withValues(alpha: 0.22)),
          ),
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl + AppSpacing.sm,
              AppSpacing.xl + AppSpacing.md,
              AppSpacing.xl + AppSpacing.sm,
              AppSpacing.xl,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: CollectorTypeGlyph(archetype: archetype, size: 112),
                ),
                // Title → Because (always visible) → expandable atmosphere.
                const SizedBox(height: 24),
                Text(
                  archetype.displayName,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: CollectibleTypography.seriesHeroTitle(
                    textTheme,
                    scheme,
                  ).copyWith(
                    fontSize: 30,
                    letterSpacing: -0.55,
                    height: 1.1,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface.withValues(alpha: 0.96),
                  ),
                ),
                if (hasBecause) ...[
                  const SizedBox(height: 12),
                  Text(
                    because,
                    textAlign: TextAlign.center,
                    style: textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurface.withValues(alpha: 0.72),
                      height: 1.4,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                Theme(
                  data: Theme.of(context).copyWith(
                    dividerColor: Colors.transparent,
                  ),
                  child: ExpansionTile(
                    key: const Key('collector_type_why_this_type'),
                    tilePadding: EdgeInsets.zero,
                    childrenPadding: const EdgeInsets.fromLTRB(4, 0, 4, 4),
                    iconColor: scheme.onSurfaceVariant.withValues(alpha: 0.45),
                    collapsedIconColor:
                        scheme.onSurfaceVariant.withValues(alpha: 0.45),
                    title: Text(
                      'Why this type',
                      textAlign: TextAlign.center,
                      style: textTheme.labelLarge?.copyWith(
                        color: scheme.onSurfaceVariant.withValues(alpha: 0.62),
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.1,
                      ),
                    ),
                    children: [
                      Text(
                        archetype.flavorText,
                        textAlign: TextAlign.center,
                        style: AppTypography.insightsFlavor(
                          textTheme,
                          scheme,
                        ).copyWith(
                          fontSize: 13.5,
                          height: 1.45,
                          color: scheme.onSurfaceVariant.withValues(
                            alpha: 0.62,
                          ),
                        ),
                      ),
                      if (hasHelper) ...[
                        const SizedBox(height: 12),
                        Text(
                          helperLine!,
                          textAlign: TextAlign.center,
                          style: textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant.withValues(
                              alpha: 0.55,
                            ),
                            height: 1.35,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                CollectorTypeRevealDashboardFooter(
                  revealedAt: identity.revealedAt,
                  showRevealAgain: showRevealAgain,
                  onRevealAgain: onRevealAgain ?? () {},
                  now: updatedAtNow,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
