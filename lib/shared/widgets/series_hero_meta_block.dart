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

    final ipStyle = density == SeriesHeroMetaDensity.hero
        ? CollectibleTypography.seriesIpLine(textTheme, scheme)
        : textTheme.labelLarge?.copyWith(
            color: scheme.onSurfaceVariant.withValues(alpha: 0.78),
            fontWeight: FontWeight.w600,
          );

    final brandStyle = density == SeriesHeroMetaDensity.hero
        ? CollectibleTypography.seriesBrandLine(textTheme, scheme)
        : textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant.withValues(alpha: 0.68),
            height: 1.25,
          );

    final metaStyle = density == SeriesHeroMetaDensity.hero
        ? CollectibleTypography.figureMeta(textTheme, scheme)
        : textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant.withValues(alpha: 0.68),
            height: 1.25,
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (ipLabel.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(ipLabel, style: ipStyle),
        ],
        if (brandLabel.isNotEmpty) ...[
          SizedBox(height: ipLabel.isNotEmpty ? 2 : 6),
          Text(brandLabel, style: brandStyle),
        ],
        if (trailingMeta != null && trailingMeta!.trim().isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(trailingMeta!.trim(), style: metaStyle),
        ],
      ],
    );
  }
}

enum SeriesHeroMetaDensity { hero, compact }
