import 'package:blindbox_app/core/theme/app_spacing.dart';
import 'package:blindbox_app/features/catalog/search/suggested_searches.dart';
import 'package:flutter/material.dart';

/// Vertical rhythm for history / suggestion lists (Catalog + Market search).
abstract final class SearchHistorySectionSpacing {
  /// Gap between the search field and the section title ([FeedSearchScreen]).
  static const double belowSearchField = AppSpacing.xs;

  /// Space under the section title before the first row.
  static const double titleBottom = 2;

  /// Vertical padding inside each row (tap target stays ≥ 44 px tall).
  static const double rowVertical = 6;

  /// Vertical padding on the Clear All control.
  static const double clearAllVertical = 5;
}

/// Reusable search history / suggestions section when the query field is empty.
///
/// Callers:
/// - [CatalogBrowseScreen] (full-screen search)
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _SearchHistorySectionTitle(title: title),
        for (final query in queries)
          SearchHistoryRow(
            label: query,
            onTap: () => onQueryTap(query),
            showDeleteButton: showDeleteButtons,
            onRemove:
                showDeleteButtons && onRemove != null ? () => onRemove!(query) : null,
          ),
        if (showClearAll) _SearchHistoryClearAll(onPressed: onClearAll),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        const _SearchHistorySectionTitle(title: 'Suggested Searches'),
        for (final suggestion in _suggestions)
          SearchHistoryRow(
            label: suggestion.displayLabel,
            onTap: () => widget.onSuggestedTap(suggestion.query),
            showDeleteButton: false,
          ),
      ],
    );
  }
}

class _SearchHistorySectionTitle extends StatelessWidget {
  const _SearchHistorySectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pageHorizontal,
        0,
        AppSpacing.pageHorizontal,
        SearchHistorySectionSpacing.titleBottom,
      ),
      child: Text(
        title,
        style: textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: 0.12,
          color: scheme.onSurfaceVariant.withValues(alpha: 0.88),
        ),
      ),
    );
  }
}

class _SearchHistoryClearAll extends StatelessWidget {
  const _SearchHistoryClearAll({required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Divider(height: 1, indent: AppSpacing.pageHorizontal),
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.pageHorizontal,
                SearchHistorySectionSpacing.clearAllVertical,
                AppSpacing.pageHorizontal,
                SearchHistorySectionSpacing.clearAllVertical,
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Clear All',
                  style: textTheme.labelLarge?.copyWith(
                    color: scheme.onSurfaceVariant.withValues(alpha: 0.75),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Single history / suggestion row — shared by recent and suggested sections.
class SearchHistoryRow extends StatelessWidget {
  const SearchHistoryRow({
    super.key,
    required this.label,
    required this.onTap,
    required this.showDeleteButton,
    this.onRemove,
  });

  final String label;
  final VoidCallback onTap;
  final bool showDeleteButton;
  final VoidCallback? onRemove;

  static const double _historyIconSize = 18;
  static const double _historyIconGap = 12;
  static const double _deleteLeadingGap = 4;
  static const double _deleteTapSize = 32;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.pageHorizontal,
          vertical: SearchHistorySectionSpacing.rowVertical,
        ),
        child: Row(
          children: [
            Icon(
              Icons.history_rounded,
              size: _historyIconSize,
              color: scheme.onSurfaceVariant.withValues(alpha: 0.55),
            ),
            const SizedBox(width: _historyIconGap),
            Expanded(
              child: Text(
                label,
                style: textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurface,
                ),
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (showDeleteButton && onRemove != null) ...[
              const SizedBox(width: _deleteLeadingGap),
              SizedBox(
                width: _deleteTapSize,
                height: _deleteTapSize,
                child: IconButton(
                  icon: Icon(
                    Icons.close_rounded,
                    size: _historyIconSize,
                    color: scheme.onSurfaceVariant.withValues(alpha: 0.55),
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: _deleteTapSize,
                    minHeight: _deleteTapSize,
                  ),
                  tooltip: 'Remove',
                  onPressed: onRemove,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
