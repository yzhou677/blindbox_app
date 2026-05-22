import 'package:blindbox_app/features/catalog/presentation/catalog_image_display.dart';
import 'package:blindbox_app/core/theme/app_radii.dart';
import 'package:blindbox_app/core/theme/collectible_shelf_shadow.dart';
import 'package:blindbox_app/core/theme/collectible_typography.dart';
import 'package:blindbox_app/features/market/presentation/market_listing_image.dart';
import 'package:blindbox_app/features/market/application/market_listings_providers.dart';
import 'package:blindbox_app/features/market/utils/market_format.dart';
import 'package:blindbox_app/features/collectible_relationship/application/collectible_relationship_providers.dart';
import 'package:blindbox_app/features/collectible_relationship/widgets/collectible_relationship_line.dart';
import 'package:blindbox_app/features/market/widgets/listing_market_signals.dart';
import 'package:blindbox_app/models/market_listing.dart';
import 'package:blindbox_app/shared/widgets/series_hero_meta_block.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class MarketDetailScreen extends ConsumerWidget {
  const MarketDetailScreen({super.key, required this.listingId});

  final String listingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final all = ref.watch(marketBrowseListingsProvider);
    MarketListing? listing;
    for (final m in all) {
      if (m.id == listingId) {
        listing = m;
        break;
      }
    }

    if (listing == null) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => context.pop(),
          ),
        ),
        body: Center(
          child: Text(
            'Not found',
            style: CollectibleTypography.figureMeta(textTheme, scheme),
          ),
        ),
      );
    }

    final c = listing.collectible;
    final accent = c.shelfAccent ?? scheme.tertiaryContainer;

    return Scaffold(
      backgroundColor: scheme.surface,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            pinned: true,
            stretch: true,
            backgroundColor: scheme.surface.withValues(alpha: 0.94),
            surfaceTintColor: scheme.surfaceTint.withValues(alpha: 0.45),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () => context.pop(),
            ),
            title: Text(
              c.series,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: CollectibleTypography.seriesHeroTitle(textTheme, scheme)
                  .copyWith(fontSize: 18),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: _MarketDetailHero(listing: listing, accent: accent),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 24, 22, 40),
              child: _MarketDetailBody(listingId: listingId, listing: listing),
            ),
          ),
        ],
      ),
    );
  }
}

class _MarketDetailHero extends StatelessWidget {
  const _MarketDetailHero({required this.listing, required this.accent});

  final MarketListing listing;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final c = listing.collectible;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: AppRadii.spotlightRadius,
        boxShadow: CollectibleShelfShadow.productShell(context, accent: accent),
      ),
      child: Material(
        color: scheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadii.spotlightRadius,
          side: BorderSide(
            color: accent.withValues(alpha: isDark ? 0.2 : 0.32),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: AppRadii.matRadius,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  accent.withValues(alpha: isDark ? 0.32 : 0.38),
                  scheme.surface.withValues(alpha: 0.06),
                ],
              ),
              border: Border.all(
                color: accent.withValues(alpha: isDark ? 0.1 : 0.16),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: AspectRatio(
                aspectRatio: 0.95,
                child: ClipRRect(
                  borderRadius: AppRadii.insetRadius,
                  child: ColoredBox(
                    color: scheme.surface.withValues(alpha: 0.5),
                    child: MarketListingImage(
                      collectible: c,
                      heroTag: listing.marketHeroTag,
                      borderRadius: BorderRadius.zero,
                      fit: BoxFit.contain,
                      displayMode: CatalogImageDisplayMode.seriesCoverHero,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MarketDetailBody extends ConsumerWidget {
  const _MarketDetailBody({
    required this.listingId,
    required this.listing,
  });

  final String listingId;
  final MarketListing listing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final c = listing.collectible;
    final up = listing.priceChangePercent > 0;
    final down = listing.priceChangePercent < 0;
    final deltaColor = up
        ? scheme.primary
        : down
            ? scheme.error
            : scheme.onSurfaceVariant;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          c.name,
          style: CollectibleTypography.figureCaption(textTheme, scheme),
        ),
        SeriesHeroMetaBlock(
          brand: c.brand,
          ipLine: c.ipLine ?? c.brand,
          trailingMeta: '${listing.listingCount} listings · ${c.releaseDateLabel}',
          density: SeriesHeroMetaDensity.compact,
        ),
        const SizedBox(height: 12),
        ListingMarketSignals(listing: listing, dense: true),
        Builder(
          builder: (context) {
            final line = ref.watch(
              relationshipHintForMarketListingProvider(listingId),
            );
            if (line == null || line.isEmpty) return const SizedBox.shrink();
            return CollectibleRelationshipLine(
              text: line,
              padding: const EdgeInsets.only(top: 10),
            );
          },
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              formatMarketUsd(listing.currentPriceUsd),
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
                letterSpacing: 0,
                height: 1.1,
              ),
            ),
            if (up || down) ...[
              const SizedBox(width: 10),
              Text(
                formatPriceChangePercent(listing.priceChangePercent),
                style: textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: deltaColor.withValues(alpha: 0.72),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
