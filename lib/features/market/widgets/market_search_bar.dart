import 'package:blindbox_app/shared/widgets/app_search_field.dart';
import 'package:flutter/material.dart';

/// Market tab search — delegates to [AppSearchField] for shared styling.
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

    return AppSearchField(
      controller: controller,
      onChanged: onChanged,
      onSubmitted: onSearchSubmitted,
      hintText: 'Search figures, series, brands…',
      suffixIcon: suffix,
    );
  }
}
