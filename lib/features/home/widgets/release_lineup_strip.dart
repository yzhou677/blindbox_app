import 'package:blindbox_app/core/theme/app_radii.dart';
import 'package:blindbox_app/core/theme/collectible_typography.dart';
import 'package:blindbox_app/features/catalog/presentation/catalog_image_display.dart';
import 'package:blindbox_app/features/home/domain/series_release.dart';
import 'package:blindbox_app/shared/widgets/catalog_image_from_key.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

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

  static const double cellExtent = 84;
  static const double gap = 14;
  static const double labelGap = 8;
  static const double listVerticalPadding = 4;

  /// Secret slots with a catalog [imageKey] show real art; blur tile only when art is unknown.
  static bool slotUsesSecretPlaceholder(ReleaseLineupSlot slot) {
    return slot.isSecret && slot.imageKey.trim().isEmpty;
  }

  /// Viewport height for the horizontal strip: fixed art + live one-line label metrics.
  ///
  /// Must grow with [MediaQuery.textScalerOf] so system font scaling does not
  /// overflow the [ListView] (the old `cellExtent + 32` budget was 1px short).
  @visibleForTesting
  static double stripHeightFor(BuildContext context) {
    final theme = Theme.of(context);
    final style = CollectibleTypography.figureMeta(
      theme.textTheme,
      theme.colorScheme,
    );
    final painter = TextPainter(
      text: TextSpan(text: 'Ag', style: style),
      textDirection: Directionality.maybeOf(context) ?? TextDirection.ltr,
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    return cellExtent +
        labelGap +
        painter.height +
        (listVerticalPadding * 2);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: stripHeightFor(context),
      child: ListView.separated(
        clipBehavior: Clip.none,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: 2,
          vertical: listVerticalPadding,
        ),
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
    final r = AppRadii.figureLineupRadius;

    final tile = ReleaseLineupStrip.slotUsesSecretPlaceholder(slot)
        ? _secretTile(r)
        : ClipRRect(borderRadius: r, child: _figureArt(slot, r));

    final baseBorder = slot.isSecret
        ? accent.withValues(alpha: 0.38)
        : scheme.outlineVariant.withValues(alpha: 0.35);

    return SizedBox(
      width: ReleaseLineupStrip.cellExtent,
      child: Column(
        mainAxisSize: MainAxisSize.min,
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
          const SizedBox(height: ReleaseLineupStrip.labelGap),
          Text(
            slot.isSecret ? 'Secret' : slot.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: CollectibleTypography.figureMeta(textTheme, scheme),
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
            Symbols.blur_on_rounded,
            size: 30,
            color: scheme.onSurfaceVariant.withValues(alpha: 0.38),
          ),
        ),
      ),
    );
  }
}
