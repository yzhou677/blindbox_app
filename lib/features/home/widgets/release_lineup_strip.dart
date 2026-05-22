import 'package:blindbox_app/features/catalog/presentation/catalog_aspect_image.dart';
import 'package:blindbox_app/features/catalog/presentation/catalog_image_display.dart';
import 'package:blindbox_app/features/home/domain/series_release.dart';
import 'package:blindbox_app/shared/widgets/catalog_image_from_key.dart';
import 'package:blindbox_app/shared/widgets/collectible_thumb_image.dart';
import 'package:flutter/material.dart';

/// Horizontal, image-first lineup browse for a [SeriesRelease].
class ReleaseLineupStrip extends StatelessWidget {
  const ReleaseLineupStrip({
    super.key,
    required this.slots,
    required this.accent,
    required this.onSlotTap,
  });

  final List<ReleaseLineupSlot> slots;
  final Color accent;
  final ValueChanged<int> onSlotTap;

  static const double cellExtent = 78;
  static const double gap = 12;

  /// Secret slots with a catalog [imageKey] show real art; blur tile only when art is unknown.
  static bool slotUsesSecretPlaceholder(ReleaseLineupSlot slot) {
    if (!slot.isSecret) return false;
    if (slot.imageKey.trim().isNotEmpty) return false;
    final url = slot.imageUrl?.trim();
    return url == null || url.isEmpty;
  }

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
    required this.onTap,
  });

  final ReleaseLineupSlot slot;
  final Color accent;
  final ColorScheme scheme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final r = BorderRadius.circular(16);

    final tile = ReleaseLineupStrip.slotUsesSecretPlaceholder(slot)
        ? _secretTile(r)
        : ClipRRect(
            borderRadius: r,
            child: _figureArt(slot, r),
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
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: r,
                  border: Border.all(color: baseBorder),
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
              color: scheme.onSurfaceVariant.withValues(alpha: 0.82),
            ),
          ),
        ],
      ),
    );
  }

  Widget _figureArt(ReleaseLineupSlot slot, BorderRadius r) {
    final key = slot.imageKey.trim();
    if (key.isNotEmpty) {
      return SizedBox(
        width: ReleaseLineupStrip.cellExtent,
        height: ReleaseLineupStrip.cellExtent,
        child: CatalogImageFromKey(
          imageKey: key,
          name: slot.name,
          seedKey: slot.slotId,
          isSecret: slot.isSecret,
          displayMode: CatalogImageDisplayMode.figureLineupCell,
          borderRadius: r,
          width: ReleaseLineupStrip.cellExtent,
          height: ReleaseLineupStrip.cellExtent,
        ),
      );
    }

    final url = slot.imageUrl?.trim();
    if (url != null && url.isNotEmpty) {
      if (CollectibleThumbImage.isAssetPath(url)) {
        return SizedBox(
          width: ReleaseLineupStrip.cellExtent,
          height: ReleaseLineupStrip.cellExtent,
          child: CollectibleThumbImage(
            imageRef: url,
            name: slot.name,
            seedKey: slot.slotId,
            catalogDisplayMode: CatalogImageDisplayMode.figureLineupCell,
            borderRadius: r,
          ),
        );
      }
      return SizedBox(
        width: ReleaseLineupStrip.cellExtent,
        height: ReleaseLineupStrip.cellExtent,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final spec = CatalogImageDisplaySpec.forMode(
              CatalogImageDisplayMode.figureLineupCell,
            );
            final dpr = MediaQuery.devicePixelRatioOf(context);
            return CatalogAspectImage.presentNetwork(
              imageUrl: url,
              fit: spec.fit,
              fillBounds: spec.fillsFrame,
              alignment: spec.alignment,
              decodeExtent: spec.memCacheDecodeExtent(constraints, dpr),
              fadeInDuration: const Duration(milliseconds: 180),
            );
          },
        ),
      );
    }

    return SizedBox(
      width: ReleaseLineupStrip.cellExtent,
      height: ReleaseLineupStrip.cellExtent,
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
