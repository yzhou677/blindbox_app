import 'package:blindbox_app/core/theme/collectible_shape.dart';
import 'package:flutter/material.dart';

/// Cozy M3 search field — draft [onChanged], immersive via [onSearchSubmitted].
class MarketSearchBar extends StatelessWidget {
  const MarketSearchBar({
    super.key,
    required this.controller,
    required this.onChanged,
    this.onSearchSubmitted,
    this.onClearSearchSession,
    this.onClearDraft,
    this.searchResultsActive = false,
    this.showClearDraft = false,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback? onSearchSubmitted;
  final VoidCallback? onClearSearchSession;
  final VoidCallback? onClearDraft;
  final bool searchResultsActive;
  final bool showClearDraft;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    Widget? suffix;
    if (searchResultsActive && onClearSearchSession != null) {
      suffix = IconButton(
        tooltip: 'Clear search',
        onPressed: onClearSearchSession,
        icon: Icon(
          Icons.close_rounded,
          color: scheme.onSurfaceVariant.withValues(alpha: 0.85),
        ),
      );
    } else if (showClearDraft && onClearDraft != null) {
      suffix = IconButton(
        tooltip: 'Clear',
        onPressed: onClearDraft,
        icon: Icon(
          Icons.clear_rounded,
          color: scheme.onSurfaceVariant.withValues(alpha: 0.75),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        onSubmitted: onSearchSubmitted != null ? (_) => onSearchSubmitted!() : null,
        textInputAction: TextInputAction.search,
        style: textTheme.bodyLarge,
        decoration: InputDecoration(
          hintText: 'Search figures, series, brands…',
          prefixIcon: Icon(
            Icons.search_rounded,
            color: scheme.onSurfaceVariant.withValues(alpha: 0.75),
          ),
          suffixIcon: suffix,
          filled: true,
          fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
          border: OutlineInputBorder(
            borderRadius: CollectibleShape.fieldRadius,
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: CollectibleShape.fieldRadius,
            borderSide: BorderSide(
              color: scheme.outlineVariant.withValues(alpha: 0.35),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: CollectibleShape.fieldRadius,
            borderSide: BorderSide(
              color: scheme.primary.withValues(alpha: 0.35),
              width: 1.5,
            ),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
        ),
      ),
    );
  }
}
