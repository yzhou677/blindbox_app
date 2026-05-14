import 'package:blindbox_app/features/home/domain/series_release.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Horizontal, image-first lineup browse for a [SeriesRelease].
class ReleaseLineupStrip extends StatelessWidget {
  const ReleaseLineupStrip({
    super.key,
    required this.slots,
    required this.accent,
  });

  final List<ReleaseLineupSlot> slots;
  final Color accent;

  static const double cellExtent = 78;
  static const double gap = 12;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: cellExtent + 30,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 2),
        physics: const BouncingScrollPhysics(),
        itemCount: slots.length,
        separatorBuilder: (context, index) => const SizedBox(width: gap),
        itemBuilder: (context, i) => _LineupCell(
          slot: slots[i],
          accent: accent,
          scheme: scheme,
        ),
      ),
    );
  }
}

class _LineupCell extends StatelessWidget {
  const _LineupCell({
    required this.slot,
    required this.accent,
    required this.scheme,
  });

  final ReleaseLineupSlot slot;
  final Color accent;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final r = BorderRadius.circular(16);

    final tile = slot.isSecret
        ? _secretTile(r)
        : ClipRRect(
            borderRadius: r,
            child: ColoredBox(
              color: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
              child: slot.imageUrl != null
                  ? CachedNetworkImage(
                      imageUrl: slot.imageUrl!,
                      width: ReleaseLineupStrip.cellExtent,
                      height: ReleaseLineupStrip.cellExtent,
                      fit: BoxFit.cover,
                      fadeInDuration: const Duration(milliseconds: 180),
                    )
                  : SizedBox(
                      width: ReleaseLineupStrip.cellExtent,
                      height: ReleaseLineupStrip.cellExtent,
                    ),
            ),
          );

    return SizedBox(
      width: ReleaseLineupStrip.cellExtent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: r,
              border: Border.all(
                color: slot.isSecret
                    ? accent.withValues(alpha: 0.38)
                    : scheme.outlineVariant.withValues(alpha: 0.35),
              ),
              boxShadow: [
                BoxShadow(
                  color: scheme.shadow.withValues(alpha: 0.06),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: ClipRRect(borderRadius: r, child: tile),
          ),
          const SizedBox(height: 6),
          Text(
            slot.isSecret ? 'Secret' : slot.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w600,
              letterSpacing: 0.02,
              color: scheme.onSurfaceVariant.withValues(alpha: 0.82),
            ),
          ),
        ],
      ),
    );
  }

  Widget _secretTile(BorderRadius r) {
    return SizedBox(
      width: ReleaseLineupStrip.cellExtent,
      height: ReleaseLineupStrip.cellExtent,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: r,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              scheme.surfaceContainerHigh.withValues(alpha: 0.95),
              Color.lerp(scheme.surfaceContainerLow, accent, 0.12)!,
            ],
          ),
        ),
        child: Center(
          child: Icon(
            Icons.blur_on_rounded,
            size: 30,
            color: scheme.onSurfaceVariant.withValues(alpha: 0.38),
          ),
        ),
      ),
    );
  }
}
