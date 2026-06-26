import 'package:blindbox_app/core/theme/app_spacing.dart';
import 'package:blindbox_app/features/catalog/search/suggested_searches.dart';
import 'package:flutter/material.dart';

/// Reusable search history / suggestions section when the query field is empty.
///
/// Callers:
/// - [CatalogBrowseScreen] (full-screen search)
/// - [AddToCollectionSheet] (bottom-sheet inline search)
/// - [MarketBrowseSearchScreen] (Market search overlay)
///
/// When [queries] is empty, renders nothing — no header, no empty placeholder.
class CatalogSearchHistorySection extends StatelessWidget {
  const CatalogSearchHistorySection({
    super.key,
    required this.queries,
    required this.onQueryTap,
    this.title = 'Recent Searches',
    this.showDeleteButtons = true,
    this.showClearAll = true,
    this.onRemove,
    this.onClearAll,
  });

  /// Most-recent-first list of queries to display.
  final List<String> queries;

  final String title;
  final bool showDeleteButtons;
  final bool showClearAll;

  /// Called when user taps a row — should fill the search field and
  /// execute the search immediately.
  final ValueChanged<String> onQueryTap;

  /// Called when user taps the × on a row (recent searches only).
  final ValueChanged<String>? onRemove;

  /// Called when user taps "Clear All" (recent searches only).
  final VoidCallback? onClearAll;

  @override
  Widget build(BuildContext context) {
    if (queries.isEmpty) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.pageHorizontal,
            0,
            AppSpacing.pageHorizontal,
            0,
          ),
          child: Text(
            title,
            style: textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: 0.12,
              color: scheme.onSurfaceVariant.withValues(alpha: 0.88),
            ),
          ),
        ),
        for (final query in queries)
          _SearchHistoryRow(
            label: query,
            onTap: () => onQueryTap(query),
            showDeleteButton: showDeleteButtons,
            onRemove:
                showDeleteButtons && onRemove != null ? () => onRemove!(query) : null,
          ),
        if (showClearAll) ...[
          const Divider(height: 1, indent: AppSpacing.pageHorizontal),
          TextButton(
            onPressed: onClearAll,
            style: TextButton.styleFrom(
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.pageHorizontal,
                6,
                AppSpacing.pageHorizontal,
                6,
              ),
              foregroundColor: scheme.onSurfaceVariant.withValues(alpha: 0.75),
            ),
            child: const Text('Clear All'),
          ),
        ],
      ],
    );
  }
}

/// Recent history when non-empty; otherwise a shuffled slice of
/// [kSuggestedSearches].
Widget searchEmptyQuerySection({
  required List<String> history,
  required ValueChanged<String> onHistoryTap,
  required ValueChanged<String> onRemove,
  required VoidCallback onClearAll,
  required ValueChanged<String> onSuggestedTap,
}) {
  if (history.isNotEmpty) {
    return CatalogSearchHistorySection(
      queries: history,
      onQueryTap: onHistoryTap,
      onRemove: onRemove,
      onClearAll: onClearAll,
    );
  }
  return _ShuffledSuggestedSearchesSection(onSuggestedTap: onSuggestedTap);
}

/// Picks [kSuggestedSearchesDisplayCount] suggestions once per mount so rebuilds
/// do not reshuffle the visible rows.
class _ShuffledSuggestedSearchesSection extends StatefulWidget {
  const _ShuffledSuggestedSearchesSection({required this.onSuggestedTap});

  final ValueChanged<String> onSuggestedTap;

  @override
  State<_ShuffledSuggestedSearchesSection> createState() =>
      _ShuffledSuggestedSearchesSectionState();
}

class _ShuffledSuggestedSearchesSectionState
    extends State<_ShuffledSuggestedSearchesSection> {
  late final List<SuggestedSearch> _suggestions = pickDisplayedSuggestedSearches();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.pageHorizontal,
            0,
            AppSpacing.pageHorizontal,
            0,
          ),
          child: Text(
            'Suggested Searches',
            style: textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: 0.12,
              color: scheme.onSurfaceVariant.withValues(alpha: 0.88),
            ),
          ),
        ),
        for (final suggestion in _suggestions)
          _SearchHistoryRow(
            label: suggestion.displayLabel,
            onTap: () => widget.onSuggestedTap(suggestion.query),
            showDeleteButton: false,
          ),
      ],
    );
  }
}

class _SearchHistoryRow extends StatelessWidget {
  const _SearchHistoryRow({
    required this.label,
    required this.onTap,
    required this.showDeleteButton,
    this.onRemove,
  });

  final String label;
  final VoidCallback onTap;
  final bool showDeleteButton;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.pageHorizontal,
          vertical: 8,
        ),
        child: Row(
          children: [
            Icon(
              Icons.history_rounded,
              size: 18,
              color: scheme.onSurfaceVariant.withValues(alpha: 0.55),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurface,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (showDeleteButton && onRemove != null)
              IconButton(
                icon: Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.55),
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                tooltip: 'Remove',
                onPressed: onRemove,
              ),
          ],
        ),
      ),
    );
  }
}
