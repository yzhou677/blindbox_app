import 'package:blindbox_app/core/theme/app_radii.dart';
import 'package:blindbox_app/core/theme/app_spacing.dart';
import 'package:blindbox_app/core/theme/app_typography.dart';
import 'package:blindbox_app/core/theme/collectible_elevation.dart';
import 'package:blindbox_app/core/theme/collectible_motion.dart';
import 'package:blindbox_app/core/theme/shelfy_symbols.dart';
import 'package:blindbox_app/features/collection/insights/domain/collector_type_identity.dart';
import 'package:blindbox_app/features/collection/insights/presentation/collector_type_copy.dart';
import 'package:blindbox_app/features/collection/insights/widgets/collector_type_glyph.dart';
import 'package:blindbox_app/features/collection/insights/widgets/collector_type_reveal_dashboard_footer.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

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
    this.onShare,
    this.updatedAtNow,
  });

  final CollectorTypeIdentity identity;
  final String? helperLine;
  final bool showRevealAgain;
  final VoidCallback? onRevealAgain;
  final VoidCallback? onShare;
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
          color: Color.lerp(scheme.surface, accent, isDark ? 0.12 : 0.08),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: AppRadii.cardRadius,
            side: BorderSide(color: accent.withValues(alpha: 0.22)),
          ),
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl + AppSpacing.xs,
              AppSpacing.lg + 2,
              AppSpacing.xl + AppSpacing.xs,
              AppSpacing.lg,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: CollectorTypeGlyph(archetype: archetype, size: 100),
                ),
                const SizedBox(height: 16),
                Text(
                  archetype.displayName,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.insightsHeroName(textTheme, scheme),
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    because,
                    textAlign: TextAlign.center,
                    style: AppTypography.insightsBecause(textTheme, scheme),
                  ),
                ),
                const SizedBox(height: 6),
                _WhyThisTypeSection(
                  flavorText: archetype.flavorText,
                  helperLine: hasHelper ? helperLine : null,
                ),
                if (onShare != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Center(
                      child: _ShareCollectorCardButton(onPressed: onShare!),
                    ),
                  ),
                if (showRevealAgain) ...[
                  const SizedBox(height: 10),
                  CollectorTypeRevealDashboardFooter(
                    revealedAt: identity.revealedAt,
                    showRevealAgain: showRevealAgain,
                    onRevealAgain: onRevealAgain ?? () {},
                    now: updatedAtNow,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ShareCollectorCardButton extends StatelessWidget {
  const _ShareCollectorCardButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(
        Symbols.ios_share_rounded,
        size: AppIconSizes.secondaryShare,
        color: scheme.onSurfaceVariant.withValues(alpha: 0.62),
      ),
      label: Text(
        'Share Collector Card',
        style: textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w600,
          fontSize: 12,
          letterSpacing: 0.05,
          color: scheme.onSurfaceVariant.withValues(alpha: 0.72),
        ),
      ),
      style: ShelfyButtonStyles.secondaryShare(scheme),
    );
  }
}

/// Quiet expand for atmosphere copy — keeps the collapsed hero short.
class _WhyThisTypeSection extends StatefulWidget {
  const _WhyThisTypeSection({required this.flavorText, this.helperLine});

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
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Why this type',
                  style: textTheme.labelLarge?.copyWith(
                    color: scheme.primary.withValues(alpha: 0.78),
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.02,
                    height: 1.2,
                  ),
                ),
                Icon(
                  _expanded
                      ? Symbols.keyboard_arrow_up_rounded
                      : Symbols.keyboard_arrow_down_rounded,
                  size: AppIconSizes.metadata,
                  color: scheme.primary.withValues(alpha: 0.62),
                ),
              ],
            ),
          ),
        ),
        AnimatedSize(
          duration: CollectibleMotion.fast,
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: !_expanded
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.fromLTRB(12, 2, 12, 0),
                  child: Column(
                    children: [
                      Text(
                        widget.flavorText,
                        textAlign: TextAlign.center,
                        style: AppTypography.insightsFlavor(textTheme, scheme)
                            .copyWith(
                              fontSize: 13.5,
                              height: 1.45,
                              color: scheme.onSurfaceVariant.withValues(
                                alpha: 0.62,
                              ),
                            ),
                      ),
                      if (widget.helperLine != null) ...[
                        const SizedBox(height: 8),
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
