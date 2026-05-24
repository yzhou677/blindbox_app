import 'package:flutter/material.dart';

/// Calm pagination control — not an infinite engagement feed.
class MarketLoadMoreFooter extends StatelessWidget {
  const MarketLoadMoreFooter({
    super.key,
    required this.onLoadMore,
    required this.loading,
  });

  final VoidCallback onLoadMore;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Center(
        child: TextButton(
          onPressed: loading ? null : onLoadMore,
          child: loading
              ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: scheme.onSurfaceVariant.withValues(alpha: 0.6),
                  ),
                )
              : Text(
                  'Load more',
                  style: textTheme.labelLarge?.copyWith(
                    color: scheme.onSurfaceVariant.withValues(alpha: 0.78),
                    fontWeight: FontWeight.w500,
                  ),
                ),
        ),
      ),
    );
  }
}
