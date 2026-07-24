import 'package:blindbox_app/core/theme/collectible_motion.dart';
import 'package:flutter/material.dart';

/// Horizontal pill chips for taxonomy brand (or similar) selection.
/// Shared by Market discovery and Collection brand filter — one visual language.
class TaxonomyBrandChipRail extends StatelessWidget {
  const TaxonomyBrandChipRail({
    super.key,
    required this.options,
    required this.selectedId,
    required this.onSelected,
    this.horizontalPadding = 20,
    this.height = 40,
    this.separatorWidth = 8,

    /// Market / Collection opt-in: shorter pills; other callers keep defaults.
    this.compact = false,
  });

  final List<({String id, String label})> options;
  final String selectedId;
  final ValueChanged<String> onSelected;
  final double horizontalPadding;
  final double height;
  final double separatorWidth;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final railHeight = compact ? 36.0 : height;

    return SizedBox(
      height: railHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
        itemCount: options.length,
        separatorBuilder: (context, index) => SizedBox(width: separatorWidth),
        itemBuilder: (context, i) {
          final o = options[i];
          final selected = selectedId == o.id;
          return _TaxonomyBrandPillChip(
            label: o.label,
            selected: selected,
            compact: compact,
            scheme: scheme,
            textTheme: textTheme,
            onTap: () => onSelected(o.id),
          );
        },
      ),
    );
  }
}

class _TaxonomyBrandPillChip extends StatelessWidget {
  const _TaxonomyBrandPillChip({
    required this.label,
    required this.selected,
    required this.compact,
    required this.scheme,
    required this.textTheme,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool compact;
  final ColorScheme scheme;
  final TextTheme textTheme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fill = selected
        ? scheme.primaryContainer.withValues(alpha: compact ? 0.72 : 0.62)
        : scheme.surfaceContainerHighest.withValues(
            alpha: compact ? 0.42 : 0.48,
          );
    final border = selected
        ? scheme.primary.withValues(alpha: compact ? 0.32 : 0.38)
        : scheme.outlineVariant.withValues(alpha: compact ? 0.28 : 0.35);
    final fg = selected
        ? scheme.onPrimaryContainer.withValues(alpha: 0.92)
        : scheme.onSurfaceVariant.withValues(alpha: 0.88);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: CollectibleMotion.fast,
          curve: Curves.easeOutCubic,
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 12 : 14,
            vertical: compact ? 6 : 8,
          ),
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: border, width: selected ? 1.15 : 1),
            boxShadow: selected && !compact
                ? [
                    BoxShadow(
                      color: scheme.primary.withValues(alpha: 0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: AnimatedDefaultTextStyle(
            duration: CollectibleMotion.fast,
            curve: Curves.easeOutCubic,
            style: textTheme.labelLarge!.copyWith(
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              letterSpacing: selected ? 0.02 : 0.1,
              color: fg,
              height: compact ? 1.1 : null,
            ),
            child: Text(label),
          ),
        ),
      ),
    );
  }
}
