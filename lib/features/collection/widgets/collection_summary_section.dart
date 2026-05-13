import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:flutter/material.dart';

/// Aggregates for the summary strip (derived from [CollectionSnapshot]).
@immutable
class CollectionAggregateStats {
  const CollectionAggregateStats({
    required this.ownedSlots,
    required this.wishlistSlots,
    required this.avgCompletionPercent,
  });

  final int ownedSlots;
  final int wishlistSlots;
  final int avgCompletionPercent;

  factory CollectionAggregateStats.fromSnapshot(CollectionSnapshot s) {
    return CollectionAggregateStats(
      ownedSlots: s.totalOwnedFigures,
      wishlistSlots: s.totalWishlistFigures,
      avgCompletionPercent: s.averageCompletionPercent,
    );
  }
}

/// Soft, premium shelf stats — not a dashboard table.
class CollectionSummarySection extends StatelessWidget {
  const CollectionSummarySection({super.key, required this.stats});

  final CollectionAggregateStats stats;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          color: scheme.surfaceContainerLow.withValues(alpha: isDark ? 0.92 : 1),
          border: Border.all(
            color: scheme.outlineVariant.withValues(alpha: isDark ? 0.35 : 0.45),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Row(
            children: [
              Expanded(
                child: _SummaryPill(
                  label: 'Owned',
                  value: '${stats.ownedSlots}',
                  hint: 'logged pulls',
                ),
              ),
              _Dot(scheme: scheme),
              Expanded(
                child: _SummaryPill(
                  label: 'Wishlist',
                  value: '${stats.wishlistSlots}',
                  hint: 'to hunt',
                ),
              ),
              _Dot(scheme: scheme),
              Expanded(
                child: _SummaryPill(
                  label: 'Avg',
                  value: '${stats.avgCompletionPercent}%',
                  hint: 'completion',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.scheme});

  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Container(
        width: 4,
        height: 4,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: scheme.primary.withValues(alpha: 0.22),
        ),
      ),
    );
  }
}

class _SummaryPill extends StatelessWidget {
  const _SummaryPill({
    required this.label,
    required this.value,
    required this.hint,
  });

  final String label;
  final String value;
  final String hint;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label.toUpperCase(),
          style: textTheme.labelSmall?.copyWith(
            letterSpacing: 0.65,
            fontWeight: FontWeight.w600,
            color: scheme.onSurfaceVariant.withValues(alpha: 0.75),
            height: 1,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: -0.5,
            height: 1,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          hint,
          textAlign: TextAlign.center,
          style: textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant.withValues(alpha: 0.82),
            height: 1.2,
          ),
        ),
      ],
    );
  }
}
