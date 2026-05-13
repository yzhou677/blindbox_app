import 'package:flutter/material.dart';

/// Two horizontal rails: brands vs IPs (collector taxonomy, still lightweight).
class MarketDiscoveryChips extends StatelessWidget {
  const MarketDiscoveryChips({
    super.key,
    required this.brandOptions,
    required this.ipOptions,
    required this.brandId,
    required this.ipId,
    required this.onBrandSelected,
    required this.onIpSelected,
  });

  final List<({String id, String label})> brandOptions;
  final List<({String id, String label})> ipOptions;
  final String brandId;
  final String ipId;
  final ValueChanged<String> onBrandSelected;
  final ValueChanged<String> onIpSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionLabel(text: 'Brand', scheme: scheme, textTheme: textTheme),
          const SizedBox(height: 6),
          _ChipRail(
            options: brandOptions,
            selectedId: brandId,
            scheme: scheme,
            textTheme: textTheme,
            onSelected: onBrandSelected,
          ),
          const SizedBox(height: 14),
          _SectionLabel(text: 'IP', scheme: scheme, textTheme: textTheme),
          const SizedBox(height: 6),
          _ChipRail(
            options: ipOptions,
            selectedId: ipId,
            scheme: scheme,
            textTheme: textTheme,
            onSelected: onIpSelected,
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({
    required this.text,
    required this.scheme,
    required this.textTheme,
  });

  final String text;
  final ColorScheme scheme;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Text(
        text,
        style: textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w600,
          letterSpacing: 0.35,
          color: scheme.onSurfaceVariant.withValues(alpha: 0.72),
        ),
      ),
    );
  }
}

class _ChipRail extends StatelessWidget {
  const _ChipRail({
    required this.options,
    required this.selectedId,
    required this.scheme,
    required this.textTheme,
    required this.onSelected,
  });

  final List<({String id, String label})> options;
  final String selectedId;
  final ColorScheme scheme;
  final TextTheme textTheme;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: options.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final o = options[i];
          final selected = selectedId == o.id;
          return _DiscoveryChip(
            label: o.label,
            selected: selected,
            scheme: scheme,
            textTheme: textTheme,
            onTap: () => onSelected(o.id),
          );
        },
      ),
    );
  }
}

class _DiscoveryChip extends StatelessWidget {
  const _DiscoveryChip({
    required this.label,
    required this.selected,
    required this.scheme,
    required this.textTheme,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final ColorScheme scheme;
  final TextTheme textTheme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fill = selected
        ? scheme.primaryContainer.withValues(alpha: 0.62)
        : scheme.surfaceContainerHighest.withValues(alpha: 0.48);
    final border = selected
        ? scheme.primary.withValues(alpha: 0.38)
        : scheme.outlineVariant.withValues(alpha: 0.35);
    final fg = selected
        ? scheme.onPrimaryContainer.withValues(alpha: 0.92)
        : scheme.onSurfaceVariant.withValues(alpha: 0.88);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: border, width: selected ? 1.15 : 1),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: scheme.primary.withValues(alpha: 0.08),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            style: textTheme.labelLarge!.copyWith(
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              letterSpacing: selected ? 0.02 : 0.1,
              color: fg,
            ),
            child: Text(label),
          ),
        ),
      ),
    );
  }
}
