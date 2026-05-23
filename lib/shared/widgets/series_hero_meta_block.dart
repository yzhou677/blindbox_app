import 'package:blindbox_app/core/theme/collectible_typography.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:flutter/material.dart';

/// Shared series subtitle block: IP, brand, optional figure/meta line.
///
/// Strips legacy `brand · ip` copy so brand is not repeated on two lines.
class SeriesHeroMetaBlock extends StatelessWidget {
  const SeriesHeroMetaBlock({
    super.key,
    required this.brand,
    required this.ipLine,
    this.trailingMeta,
    this.density = SeriesHeroMetaDensity.hero,
  });

  final String brand;
  final String ipLine;
  final String? trailingMeta;
  final SeriesHeroMetaDensity density;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final ipLabel = shelfIpLabelFromBrandLine(brand: brand, line: ipLine);
    final brandLabel = brand.trim();
    final showBrand = brandLabel.isNotEmpty &&
        (ipLabel.isEmpty ||
            ipLabel.toLowerCase() != brandLabel.toLowerCase());

    final topGap = switch (density) {
      SeriesHeroMetaDensity.sheet => 5.0,
      SeriesHeroMetaDensity.compact => 6.0,
      SeriesHeroMetaDensity.hero => 6.0,
    };
    final lineGap = switch (density) {
      SeriesHeroMetaDensity.sheet => 3.0,
      SeriesHeroMetaDensity.compact => 2.0,
      SeriesHeroMetaDensity.hero => 2.0,
    };
    final trailingGap = switch (density) {
      SeriesHeroMetaDensity.sheet => 5.0,
      _ => 6.0,
    };

    final ipStyle = density == SeriesHeroMetaDensity.hero
        ? CollectibleTypography.seriesIpLine(textTheme, scheme)
        : textTheme.labelLarge?.copyWith(
            color: scheme.onSurfaceVariant.withValues(alpha: 0.78),
            fontWeight: FontWeight.w600,
            height: density == SeriesHeroMetaDensity.sheet ? 1.28 : null,
          );

    final sheetMetaHeight = density == SeriesHeroMetaDensity.sheet ? 1.32 : 1.25;

    final brandStyle = density == SeriesHeroMetaDensity.hero
        ? CollectibleTypography.seriesBrandLine(textTheme, scheme)
        : textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant.withValues(alpha: 0.68),
            height: sheetMetaHeight,
          );

    final metaStyle = density == SeriesHeroMetaDensity.hero
        ? CollectibleTypography.figureMeta(textTheme, scheme)
        : textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant.withValues(alpha: 0.68),
            height: sheetMetaHeight,
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (ipLabel.isNotEmpty) ...[
          SizedBox(height: topGap),
          Text(ipLabel, style: ipStyle),
        ],
        if (showBrand) ...[
          SizedBox(height: ipLabel.isNotEmpty ? lineGap : topGap),
          Text(brandLabel, style: brandStyle),
        ],
        if (trailingMeta != null && trailingMeta!.trim().isNotEmpty) ...[
          SizedBox(height: trailingGap),
          Text(trailingMeta!.trim(), style: metaStyle),
        ],
      ],
    );
  }
}

enum SeriesHeroMetaDensity { hero, compact, sheet }
