import 'package:flutter/material.dart';

/// Top-of-Market browse chips — horizontal, cozy, not enterprise filters.
class MarketDiscoveryChips extends StatelessWidget {
  const MarketDiscoveryChips({
    super.key,
    required this.selectedId,
    required this.onSelected,
  });

  final String selectedId;
  final ValueChanged<String> onSelected;

  static const List<({String id, String label})> options = [
    (id: 'all', label: 'All'),
    (id: 'pop_mart', label: 'POP MART'),
    (id: 'hirono', label: 'Hirono'),
    (id: 'labubu', label: 'Labubu'),
    (id: 'skullpanda', label: 'Skullpanda'),
    (id: 'under_100', label: 'Under \$100'),
    (id: 'rare', label: 'Rare'),
    (id: 'trending', label: 'Trending'),
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 2),
      child: SizedBox(
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
