import 'package:blindbox_app/core/theme/app_spacing.dart';
import 'package:flutter/material.dart';

/// Reusable "Recent Searches" section rendered when the search field is empty
/// and history is non-empty.
///
/// Callers:
/// - [CatalogBrowseScreen] (full-screen search)
/// - [AddToCollectionSheet] (bottom-sheet inline search)
///
/// When [queries] is empty, renders nothing — no header, no empty placeholder.
class CatalogSearchHistorySection extends StatelessWidget {
  const CatalogSearchHistorySection({
    super.key,
    required this.queries,
    required this.onQueryTap,
    required this.onRemove,
    required this.onClearAll,
  });

  /// Most-recent-first list of saved queries.
  final List<String> queries;

  /// Called when user taps a history row — should fill the search field and
  /// execute the search immediately.
  final ValueChanged<String> onQueryTap;

  /// Called when user taps the × on a row.
  final ValueChanged<String> onRemove;

  /// Called when user taps "Clear All".
  final VoidCallback onClearAll;

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
            4,
          ),
          child: Text(
            'Recent Searches',
            style: textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: 0.12,
              color: scheme.onSurfaceVariant.withValues(alpha: 0.88),
            ),
          ),
        ),
        for (final query in queries)
          _HistoryRow(
            query: query,
            onTap: () => onQueryTap(query),
            onRemove: () => onRemove(query),
          ),
        const Divider(height: 1, indent: AppSpacing.pageHorizontal),
        TextButton(
          onPressed: onClearAll,
          style: TextButton.styleFrom(
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.pageHorizontal,
              AppSpacing.sm,
              AppSpacing.pageHorizontal,
              AppSpacing.sm,
            ),
            foregroundColor: scheme.onSurfaceVariant.withValues(alpha: 0.75),
          ),
          child: const Text('Clear All'),
        ),
      ],
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({
    required this.query,
    required this.onTap,
    required this.onRemove,
  });

  final String query;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.pageHorizontal,
          vertical: 10,
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
                query,
                style: textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurface,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
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
