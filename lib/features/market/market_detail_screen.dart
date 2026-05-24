import 'package:blindbox_app/core/layout/feed_rhythm.dart';
import 'package:blindbox_app/features/catalog/presentation/catalog_image_display.dart';
import 'package:blindbox_app/core/theme/app_radii.dart';
import 'package:blindbox_app/core/theme/collectible_shelf_shadow.dart';
import 'package:blindbox_app/core/theme/collectible_typography.dart';
import 'package:blindbox_app/features/market/presentation/market_listing_image.dart';
import 'package:blindbox_app/features/market/application/market_listing_detail_provider.dart';
import 'package:blindbox_app/features/market/application/market_listing_lookup.dart';
import 'package:blindbox_app/features/market/presentation/collectible_market_mood_copy.dart';
import 'package:blindbox_app/features/market/utils/open_market_listing_url.dart';
import 'package:blindbox_app/features/market/utils/market_format.dart';
import 'package:blindbox_app/features/collectible_relationship/application/collectible_relationship_providers.dart';
import 'package:blindbox_app/features/collectible_relationship/widgets/collectible_relationship_line.dart';
import 'package:blindbox_app/features/market/domain/chasers_heat_entry.dart';
import 'package:blindbox_app/features/market/domain/market_listing_detail.dart';
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
    final listing = ref.watch(marketListingByIdProvider(listingId));
    final chaserEntry = ref.watch(chaserEntryByListingIdProvider(listingId));

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
    final appBarTitle = chaserEntry?.identityLabel ??
        (c.name.trim().isNotEmpty ? c.name : c.series);

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
              appBarTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: CollectibleTypography.seriesHeroTitle(textTheme, scheme)
                  .copyWith(fontSize: 18),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                FeedRhythm.detailHeroToBodyGap,
                20,
                0,
              ),
              child: _MarketDetailHero(listingId: listingId, listing: listing, accent: accent),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                22,
                FeedRhythm.detailBodyTopGap,
                22,
                FeedRhythm.detailBodyBottomGap,
              ),
              child: _MarketDetailBody(
                listingId: listingId,
                listing: listing,
                chaserEntry: chaserEntry,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MarketDetailHero extends ConsumerWidget {
  const _MarketDetailHero({
    required this.listingId,
    required this.listing,
    required this.accent,
  });

  final String listingId;
  final MarketListing listing;
  final Color accent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final c = listing.collectible;
    final detail = ref.watch(marketListingDetailProvider(listingId));
    final heroImage = detail.maybeWhen(
      data: (value) => value?.imageUrl,
      orElse: () => null,
    );
    final aspect = CatalogImageDisplaySpec.aspectRatioFor(
          CatalogImageDisplayMode.seriesCoverHero,
        ) ??
        1.0;

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
          padding: const EdgeInsets.all(FeedRhythm.detailHeroOuterPadding),
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
              padding:
                  const EdgeInsets.all(FeedRhythm.detailHeroInnerPadding),
              child: AspectRatio(
                aspectRatio: aspect,
                child: ClipRRect(
                  borderRadius: AppRadii.insetRadius,
                  child: ColoredBox(
                    color: scheme.surface.withValues(alpha: 0.5),
                    child: MarketListingImage(
                      collectible: c,
                      imageUrlOverride: heroImage,
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
    this.chaserEntry,
  });

  final String listingId;
  final MarketListing listing;
  final ChasersHeatEntry? chaserEntry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final c = listing.collectible;
    final detailAsync = ref.watch(marketListingDetailProvider(listingId));
    final detail = detailAsync.valueOrNull;
    final up = listing.priceChangePercent > 0;
    final down = listing.priceChangePercent < 0;
    final deltaColor = up
        ? scheme.primary
        : down
            ? scheme.error
            : scheme.onSurfaceVariant;
    final listingTitle = c.name.trim();
    final showFigureSubtitle = chaserEntry != null
        ? listingTitle.isNotEmpty
        : listingTitle.isNotEmpty &&
            listingTitle.toLowerCase() != c.series.trim().toLowerCase();
    final release = c.releaseDateLabel.trim();
    final marketFacts = [
      chaserEntry != null
          ? CollectibleMarketMoodCopy.recentlyActiveLine()
          : CollectibleMarketMoodCopy.listingDetailLine(listing),
      if (release.isNotEmpty) 'Released $release',
    ].join(' · ');
    final description = detail?.shortDescription?.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          chaserEntry?.identityLabel ?? c.series,
          style: CollectibleTypography.seriesHeroTitle(textTheme, scheme),
        ),
        if (showFigureSubtitle) ...[
          const SizedBox(height: 4),
          Text(
            listingTitle,
            style: CollectibleTypography.figureCaption(textTheme, scheme),
          ),
        ],
        SeriesHeroMetaBlock(
          brand: c.brand,
          ipLine: chaserEntry?.ipLabel ?? c.ipLine?.trim() ?? '',
          density: SeriesHeroMetaDensity.compact,
        ),
        const SizedBox(height: 8),
        Text(
          marketFacts,
          style: CollectibleTypography.figureMeta(textTheme, scheme),
        ),
        const SizedBox(height: 6),
        ListingMarketSignals(listing: listing, dense: true),
        const SizedBox(height: 12),
        _MarketListingFacts(listing: listing, detail: detail),
        if (detailAsync.isLoading && detail == null) ...[
          const SizedBox(height: 12),
          LinearProgressIndicator(
            minHeight: 2,
            color: scheme.primary.withValues(alpha: 0.55),
            backgroundColor: scheme.surfaceContainerHighest,
          ),
        ],
        if (description != null && description.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            'About this listing',
            style: CollectibleTypography.figureMeta(textTheme, scheme).copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            description,
            maxLines: 5,
            overflow: TextOverflow.ellipsis,
            style: textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant.withValues(alpha: 0.88),
              height: 1.35,
            ),
          ),
        ],
        Builder(
          builder: (context) {
            final line = ref.watch(
              relationshipHintForMarketListingProvider(listingId),
            );
            if (line == null || line.isEmpty) return const SizedBox.shrink();
            return CollectibleRelationshipLine(
              text: line,
              padding: const EdgeInsets.only(top: 8),
            );
          },
        ),
        const SizedBox(height: 14),
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
        if (_listingUrl(listing, detail) != null) ...[
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton.tonalIcon(
              onPressed: () => openMarketListingUrl(
                context,
                _listingUrl(listing, detail),
              ),
              icon: const Icon(Icons.open_in_new_rounded, size: 18),
              label: Text(
                listing.providerId == 'ebay' ? 'View on eBay' : 'View listing',
              ),
            ),
          ),
        ],
      ],
    );
  }
}

String? _listingUrl(MarketListing listing, MarketListingDetail? detail) {
  final fromDetail = detail?.listingUrl.trim();
  if (fromDetail != null && fromDetail.isNotEmpty) return fromDetail;
  final fromListing = listing.externalListingUrl?.trim();
  if (fromListing != null && fromListing.isNotEmpty) return fromListing;
  return null;
}

class _MarketListingFacts extends StatelessWidget {
  const _MarketListingFacts({
    required this.listing,
    required this.detail,
  });

  final MarketListing listing;
  final MarketListingDetail? detail;

  @override
  Widget build(BuildContext context) {
    final listed = formatMarketListingDate(listing.itemCreationDate);
    final seller = _sellerLine(listing, detail);
    final quantity =
        detail == null ? null : formatMarketListingQuantityLine(detail!);
    final rows = <({String label, String value})>[
      if (detail?.condition case final condition?)
        (label: 'Condition', value: condition),
      if (quantity != null) (label: 'Quantity', value: quantity),
      if (seller case final sellerLine?) (label: 'Seller', value: sellerLine),
      if (listed case final listedLine?) (label: 'Listed', value: listedLine),
      if (detail?.shippingSummary case final shipping?)
        (label: 'Shipping', value: shipping),
    ];

    if (rows.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final row in rows) ...[
          _MarketDetailFactRow(label: row.label, value: row.value),
          const SizedBox(height: 8),
        ],
      ],
    );
  }

  String? _sellerLine(MarketListing listing, MarketListingDetail? detail) {
    final fromDetail = detail?.sellerLine?.trim();
    if (fromDetail != null && fromDetail.isNotEmpty) return fromDetail;
    final username = listing.sellerUsername?.trim();
    if (username != null && username.isNotEmpty) return username;
    return null;
  }
}

class _MarketDetailFactRow extends StatelessWidget {
  const _MarketDetailFactRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final labelStyle = CollectibleTypography.figureMeta(textTheme, scheme)
        .copyWith(fontWeight: FontWeight.w600);
    final valueStyle = textTheme.bodyMedium?.copyWith(
      color: scheme.onSurfaceVariant.withValues(alpha: 0.9),
      height: 1.25,
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 84,
          child: Text(label, style: labelStyle),
        ),
        Expanded(child: Text(value, style: valueStyle)),
      ],
    );
  }
}
