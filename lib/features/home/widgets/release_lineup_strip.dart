import 'package:blindbox_app/features/home/domain/series_release.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Horizontal, image-first lineup browse for a [SeriesRelease].
class ReleaseLineupStrip extends StatelessWidget {
  const ReleaseLineupStrip({
    super.key,
    required this.slots,
    required this.accent,
    this.selectedIndex = -1,
    required this.onSlotTap,
  });

  final List<ReleaseLineupSlot> slots;
  final Color accent;

  /// Index of the slot whose floating preview is open, or `-1` for none.
  final int selectedIndex;
  final ValueChanged<int> onSlotTap;

  static const double cellExtent = 78;
  static const double gap = 12;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: cellExtent + 36,
      child: ListView.separated(
        clipBehavior: Clip.none,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
        physics: const BouncingScrollPhysics(),
        itemCount: slots.length,
        separatorBuilder: (context, index) => const SizedBox(width: gap),
        itemBuilder: (context, i) => _LineupCell(
          slot: slots[i],
          accent: accent,
          scheme: scheme,
          isSelected: selectedIndex >= 0 && i == selectedIndex,
          onTap: () => onSlotTap(i),
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
    required this.isSelected,
    required this.onTap,
  });

  final ReleaseLineupSlot slot;
  final Color accent;
  final ColorScheme scheme;
  final bool isSelected;
  final VoidCallback onTap;

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

    final baseBorder = slot.isSecret
        ? accent.withValues(alpha: 0.38)
        : scheme.outlineVariant.withValues(alpha: 0.35);

    return SizedBox(
      width: ReleaseLineupStrip.cellExtent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: r,
              splashColor: accent.withValues(alpha: 0.12),
              highlightColor: accent.withValues(alpha: 0.06),
              child: AnimatedScale(
                scale: isSelected ? 1.04 : 1.0,
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  decoration: BoxDecoration(
                    borderRadius: r,
                    border: Border.all(
                      color: isSelected ? accent.withValues(alpha: 0.72) : baseBorder,
                      width: isSelected ? 2.25 : 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: scheme.shadow.withValues(alpha: isSelected ? 0.1 : 0.06),
                        blurRadius: isSelected ? 12 : 8,
                        offset: Offset(0, isSelected ? 4 : 3),
                      ),
                    ],
                    color: isSelected
                        ? Color.lerp(scheme.surfaceContainerLow, accent, 0.08)!
                            .withValues(alpha: 0.55)
                        : null,
                  ),
                  child: ClipRRect(borderRadius: r, child: tile),
                ),
              ),
            ),
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
              color: scheme.onSurfaceVariant.withValues(alpha: isSelected ? 0.92 : 0.82),
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
