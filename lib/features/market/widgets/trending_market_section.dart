import 'package:blindbox_app/core/layout/feed_rhythm.dart';
import 'package:blindbox_app/core/theme/collectible_shelf_shadow.dart';
import 'package:blindbox_app/core/theme/collectible_shape.dart';
import 'package:blindbox_app/features/home/widgets/collectible_network_image.dart';
import 'package:blindbox_app/features/market/utils/market_format.dart';
import 'package:blindbox_app/models/market_listing.dart';
import 'package:blindbox_app/shared/widgets/collectible_section_header.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

const double _kTrendingCardWidth = 168;

/// Horizontal “what’s moving” rail — visual-first, not a ticker tape.
/// Wrap with [SliverToBoxAdapter] inside scroll views.
class TrendingMarketSection extends StatelessWidget {
  const TrendingMarketSection({super.key, required this.items});

  final List<MarketListing> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CollectibleSectionHeader(
          title: 'Trending',
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
          titleAccessory: Icon(
            Icons.local_fire_department_rounded,
            size: 17,
            color: Color.lerp(scheme.secondary, scheme.primary, 0.42)!.withValues(alpha: 0.62),
          ),
        ),
        const SizedBox(height: FeedRhythm.sectionHeaderToRail),
        SizedBox(
          height: 214,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: items.length,
            separatorBuilder: (context, index) => SizedBox(width: FeedRhythm.horizontalRailCardGap),
            itemBuilder: (context, index) {
              return _TrendingMiniCard(listing: items[index]);
            },
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _TrendingMiniCard extends StatelessWidget {
  const _TrendingMiniCard({required this.listing});

  final MarketListing listing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final c = listing.collectible;
    final accent = c.shelfAccent ?? scheme.tertiaryContainer;
    final outerRadius = CollectibleShape.shellRadius;
    final isDark = theme.brightness == Brightness.dark;

    return SizedBox(
      width: _kTrendingCardWidth,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: outerRadius,
          boxShadow: CollectibleShelfShadow.productShell(context, accent: accent),
        ),
        child: Material(
          color: scheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: outerRadius,
            side: BorderSide(
              color: accent.withValues(alpha: isDark ? 0.18 : 0.32),
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => context.push('/market/listing/${listing.id}'),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: CollectibleShape.matRadius,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color.lerp(scheme.surface, accent, 0.32)!
                                .withValues(alpha: isDark ? 0.36 : 0.52),
                            accent.withValues(alpha: 0.32),
                            scheme.surface.withValues(alpha: 0.08),
                          ],
                          stops: const [0.0, 0.45, 1.0],
                        ),
                        border: Border.all(
                          color: accent.withValues(alpha: isDark ? 0.12 : 0.2),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(6),
                        child: ClipRRect(
                          borderRadius: CollectibleShape.insetRadius,
                          child: ColoredBox(
                            color: scheme.surface.withValues(alpha: 0.55),
                            child: CollectibleNetworkImage(
                              collectible: c,
                              borderRadius: CollectibleShape.insetRadius,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    c.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.08,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        formatMarketUsd(listing.currentPriceUsd),
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _MiniDelta(percent: listing.priceChangePercent),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniDelta extends StatelessWidget {
  const _MiniDelta({required this.percent});

  final double percent;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final up = percent > 0;
    final down = percent < 0;
    final color = up
        ? scheme.primary
        : down
            ? scheme.error
            : scheme.onSurfaceVariant;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: up ? 0.14 : down ? 0.12 : 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        formatPriceChangePercent(percent),
        style: textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w700,
          color: color.withValues(alpha: 0.92),
          letterSpacing: 0.1,
        ),
      ),
    );
  }
}
