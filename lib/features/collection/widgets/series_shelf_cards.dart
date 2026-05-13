import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:flutter/material.dart';

/// One series row on the shelf (official or custom).
class SeriesShelfCard extends StatelessWidget {
  const SeriesShelfCard({
    super.key,
    required this.series,
    required this.progress,
    required this.onOpen,
    this.onRemove,
  });

  final SeriesDefinition series;
  final SeriesProgressCounts progress;
  final VoidCallback onOpen;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final chaseCount = series.figures.where((f) => f.isSecret).length;
    final chaseLabel = chaseCount > 0 ? '$chaseCount chase in set' : null;
    final extra = series.notes ?? chaseLabel;

    return _SeriesMatShell(
      accent: series.shelfAccent,
      onTap: onOpen,
      trailing: onRemove == null
          ? null
          : IconButton(
              icon: const Icon(Icons.delete_outline_rounded),
              tooltip: 'Remove line',
              onPressed: onRemove,
            ),
      child: _SeriesMatContent(
        title: series.name,
        subtitle: '${series.ipName} · ${series.brand}',
        extraLine: extra,
        totalFigures: series.figureCount,
        owned: progress.owned,
        wishlist: progress.wishlist,
        missing: progress.missing,
        completion: progress.completion(series.figureCount),
      ),
    );
  }
}

class _SeriesMatShell extends StatelessWidget {
  const _SeriesMatShell({
    required this.accent,
    required this.onTap,
    required this.child,
    this.trailing,
  });

  final Color accent;
  final VoidCallback onTap;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final radius = BorderRadius.circular(22);

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: [
            BoxShadow(
              color: Color.lerp(scheme.shadow, accent, 0.08)!
                  .withValues(alpha: isDark ? 0.32 : 0.08),
              blurRadius: 20,
              offset: const Offset(0, 10),
              spreadRadius: -4,
            ),
          ],
        ),
        child: Material(
          color: scheme.surfaceContainerLow,
          shape: RoundedRectangleBorder(
            borderRadius: radius,
            side: BorderSide(
              color: accent.withValues(alpha: isDark ? 0.22 : 0.38),
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: InkWell(
                  onTap: onTap,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 4,
                          height: 52,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(999),
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                accent.withValues(alpha: 0.95),
                                Color.lerp(accent, scheme.primary, 0.12)!.withValues(alpha: 0.45),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(child: child),
                      ],
                    ),
                  ),
                ),
              ),
              if (trailing != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4, right: 2),
                  child: trailing!,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SeriesMatContent extends StatelessWidget {
  const _SeriesMatContent({
    required this.title,
    required this.subtitle,
    required this.totalFigures,
    required this.owned,
    required this.wishlist,
    required this.missing,
    required this.completion,
    this.extraLine,
  });

  final String title;
  final String subtitle;
  final String? extraLine;
  final int totalFigures;
  final int owned;
  final int wishlist;
  final int missing;
  final double completion;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: -0.14,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: textTheme.labelLarge?.copyWith(
            color: scheme.onSurfaceVariant.withValues(alpha: 0.78),
            fontWeight: FontWeight.w500,
            letterSpacing: 0.06,
          ),
        ),
        if (extraLine != null) ...[
          const SizedBox(height: 4),
          Text(
            extraLine!,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant.withValues(alpha: 0.65),
              height: 1.25,
            ),
          ),
        ],
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: completion.clamp(0.0, 1.0),
            minHeight: 5,
            backgroundColor: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
            color: scheme.primary.withValues(alpha: 0.45),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          '$owned / $totalFigures owned · $wishlist wish · $missing missing',
          style: textTheme.labelMedium?.copyWith(
            color: scheme.onSurfaceVariant.withValues(alpha: 0.82),
            fontWeight: FontWeight.w500,
            letterSpacing: 0.02,
          ),
        ),
      ],
    );
  }
}
