import 'package:blindbox_app/features/home/widgets/collectible_network_image.dart';
import 'package:blindbox_app/features/market/application/market_listings_providers.dart';
import 'package:blindbox_app/features/market/utils/market_format.dart';
import 'package:blindbox_app/features/market/widgets/listing_market_signals.dart';
import 'package:blindbox_app/models/market_listing.dart';
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
          title: const Text('Market'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => context.pop(),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'This listing is not in the mock catalog.',
              textAlign: TextAlign.center,
              style: textTheme.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
            ),
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
              c.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                letterSpacing: -0.12,
              ),
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
              padding: const EdgeInsets.fromLTRB(22, 28, 22, 40),
              child: _MarketDetailBody(listing: listing, accent: accent),
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
    final brightness = Theme.of(context).brightness;
    final outerRadius = BorderRadius.circular(26);
    final c = listing.collectible;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: outerRadius,
        boxShadow: [
          BoxShadow(
            color: Color.lerp(scheme.shadow, accent, 0.1)!
                .withValues(alpha: brightness == Brightness.dark ? 0.4 : 0.1),
            blurRadius: 34,
            offset: const Offset(0, 16),
            spreadRadius: -7,
          ),
        ],
      ),
      child: Material(
        color: scheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: outerRadius,
          side: BorderSide(
            color: accent.withValues(alpha: brightness == Brightness.dark ? 0.2 : 0.34),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  accent.withValues(alpha: 0.38),
                  scheme.surface.withValues(alpha: 0.1),
                ],
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: AspectRatio(
                aspectRatio: 0.92,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: ColoredBox(
                    color: scheme.surface.withValues(alpha: 0.72),
                    child: CollectibleNetworkImage(
                      collectible: c,
                      heroTag: listing.marketHeroTag,
                      borderRadius: BorderRadius.circular(14),
                      fit: BoxFit.contain,
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

class _MarketDetailBody extends StatelessWidget {
  const _MarketDetailBody({required this.listing, required this.accent});

  final MarketListing listing;
  final Color accent;

  @override
  Widget build(BuildContext context) {
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
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: scheme.primaryContainer.withValues(alpha: 0.52),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: scheme.primary.withValues(alpha: 0.16)),
          ),
          child: Text(
            c.series,
            style: textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w600,
              letterSpacing: 0.14,
              height: 1.12,
              color: scheme.onPrimaryContainer.withValues(alpha: 0.9),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          c.name,
          style: textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: -0.38,
            height: 1.12,
          ),
        ),
        const SizedBox(height: 18),
        ListingMarketSignals(listing: listing, dense: true),
        const SizedBox(height: 14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              formatMarketUsd(listing.currentPriceUsd),
              style: textTheme.headlineLarge?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: -0.55,
                height: 1,
              ),
            ),
            const SizedBox(width: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: deltaColor.withValues(alpha: up ? 0.14 : down ? 0.12 : 0.08),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                formatPriceChangePercent(listing.priceChangePercent),
                style: textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: deltaColor.withValues(alpha: 0.92),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 22),
        _SoftMarketTile(
          icon: Icons.storefront_outlined,
          label: 'Brand',
          value: c.brand,
          tint: accent.withValues(alpha: 0.2),
        ),
        if (listing.watchingCount > 0) ...[
          const SizedBox(height: 12),
          _SoftMarketTile(
            icon: Icons.visibility_outlined,
            label: 'Shelf interest',
            value: '${listing.watchingCount} collectors watching (mock)',
            tint: accent.withValues(alpha: 0.12),
          ),
        ],
        const SizedBox(height: 12),
        _SoftMarketTile(
          icon: Icons.layers_outlined,
          label: 'Active listings',
          value: '${listing.listingCount} open offers (mock)',
          tint: accent.withValues(alpha: 0.16),
        ),
        const SizedBox(height: 12),
        _SoftMarketTile(
          icon: Icons.calendar_today_outlined,
          label: 'Release',
          value: c.releaseDateLabel,
          tint: accent.withValues(alpha: 0.14),
        ),
      ],
    );
  }
}

class _SoftMarketTile extends StatelessWidget {
  const _SoftMarketTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.tint,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          tint,
          scheme.surfaceContainerHigh.withValues(alpha: 0.35),
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 22, color: scheme.onSurfaceVariant.withValues(alpha: 0.75)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: textTheme.labelMedium?.copyWith(
                      color: scheme.onSurfaceVariant.withValues(alpha: 0.85),
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w500,
                      height: 1.28,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
