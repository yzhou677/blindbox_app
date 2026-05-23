import 'package:blindbox_app/core/layout/feed_rhythm.dart';
import 'package:blindbox_app/core/theme/collectible_typography.dart';
import 'package:blindbox_app/shared/widgets/series_hero_meta_block.dart';
import 'package:flutter/material.dart';

/// Drag pill + optional series/editorial header for bottom sheets.
class CollectibleSheetChrome extends StatelessWidget {
  const CollectibleSheetChrome({
    super.key,
    this.seriesTitle,
    this.brand,
    this.ipLine,
    this.trailingMeta,
    this.editorialTitle,
    this.editorialSubtitle,
    this.padding = const EdgeInsets.only(top: FeedRhythm.sheetChromeTop),
  });

  final String? seriesTitle;
  final String? brand;
  final String? ipLine;
  final String? trailingMeta;
  final String? editorialTitle;
  final String? editorialSubtitle;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Center(child: CollectibleSheetDragHandle()),
          if (editorialTitle != null) ...[
            SizedBox(height: FeedRhythm.sheetHeaderAfterHandle),
            Text(
              editorialTitle!,
              style: CollectibleTypography.seriesHeroTitle(textTheme, scheme),
            ),
            if (editorialSubtitle != null) ...[
              const SizedBox(height: 6),
              Text(
                editorialSubtitle!,
                style: CollectibleTypography.seriesBrandLine(textTheme, scheme),
              ),
            ],
          ] else if (seriesTitle != null) ...[
            SizedBox(height: FeedRhythm.sheetHeaderAfterHandle),
            Text(
              seriesTitle!,
              style: CollectibleTypography.seriesHeroTitle(textTheme, scheme),
            ),
            if (brand != null &&
                ipLine != null &&
                (brand!.trim().isNotEmpty || ipLine!.trim().isNotEmpty))
              SeriesHeroMetaBlock(
                brand: brand!,
                ipLine: ipLine!,
                trailingMeta: trailingMeta,
                density: SeriesHeroMetaDensity.sheet,
              )
            else if (trailingMeta != null && trailingMeta!.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                trailingMeta!.trim(),
                style: CollectibleTypography.figureMeta(textTheme, scheme),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

/// Shared drag affordance for sheets and fullscreen gallery dismiss.
class CollectibleSheetDragHandle extends StatelessWidget {
  const CollectibleSheetDragHandle({super.key, this.color});

  final Color? color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: color ?? scheme.outlineVariant.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }
}
