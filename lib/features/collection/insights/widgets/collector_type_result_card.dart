import 'package:blindbox_app/core/theme/app_radii.dart';
import 'package:blindbox_app/core/theme/app_spacing.dart';
import 'package:blindbox_app/core/theme/app_typography.dart';
import 'package:blindbox_app/core/theme/collectible_elevation.dart';
import 'package:blindbox_app/core/theme/collectible_typography.dart';
import 'package:blindbox_app/features/collection/insights/domain/collector_type_identity.dart';
import 'package:blindbox_app/features/collection/insights/presentation/collector_type_copy.dart';
import 'package:blindbox_app/features/collection/insights/widgets/collector_type_glyph.dart';
import 'package:blindbox_app/features/collection/insights/widgets/collector_type_reveal_dashboard_footer.dart';
import 'package:flutter/material.dart';

/// Hero identity surface for the revealed collector type — visual anchor of Insights.
///
/// Collapsed layers: mascot → title → Because → “Why this type” → updated.
/// Flavor + journey helper live only inside the expandable section.
///
/// Because copy: [CollectorTypeCopy.becauseLineFor] only — never archetype switch.
class CollectorTypeResultCard extends StatelessWidget {
  const CollectorTypeResultCard({
    super.key,
    required this.identity,
    this.helperLine,
    this.showRevealAgain = false,
    this.onRevealAgain,
    this.updatedAtNow,
  });

  final CollectorTypeIdentity identity;
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
    final because = CollectorTypeCopy.becauseLineFor(identity);
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
                const SizedBox(height: 8),
                _WhyThisTypeSection(
                  flavorText: archetype.flavorText,
                  helperLine: hasHelper ? helperLine : null,
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

/// Quiet expand for atmosphere copy — keeps the collapsed hero short.
class _WhyThisTypeSection extends StatefulWidget {
  const _WhyThisTypeSection({
    required this.flavorText,
    this.helperLine,
  });

  final String flavorText;
  final String? helperLine;

  @override
  State<_WhyThisTypeSection> createState() => _WhyThisTypeSectionState();
}

class _WhyThisTypeSectionState extends State<_WhyThisTypeSection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          key: const Key('collector_type_why_this_type'),
          onTap: () => setState(() => _expanded = !_expanded),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Why this type',
                  style: textTheme.labelLarge?.copyWith(
                    color: scheme.onSurfaceVariant.withValues(alpha: 0.62),
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.1,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  _expanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  size: 18,
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.45),
                ),
              ],
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: !_expanded
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
                  child: Column(
                    children: [
                      Text(
                        widget.flavorText,
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
                      if (widget.helperLine != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          widget.helperLine!,
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
        ),
      ],
    );
  }
}
