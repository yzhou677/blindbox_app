import 'package:blindbox_app/core/layout/feed_rhythm.dart';
import 'package:blindbox_app/features/market/catalog/market_listing_filters.dart';
import 'package:blindbox_app/shared/widgets/collectible_section_header.dart';
import 'package:blindbox_app/features/market/catalog/market_taxonomy.dart';
import 'package:blindbox_app/features/market/data/mock_market_listings.dart';
import 'package:blindbox_app/features/market/widgets/market_discovery_chips.dart';
import 'package:blindbox_app/features/market/widgets/market_listing_card.dart';
import 'package:blindbox_app/features/market/widgets/market_search_bar.dart';
import 'package:blindbox_app/features/market/widgets/trending_market_section.dart';
import 'package:blindbox_app/models/market_listing.dart';
import 'package:flutter/material.dart';

class MarketScreen extends StatefulWidget {
  const MarketScreen({super.key});

  @override
  State<MarketScreen> createState() => _MarketScreenState();
}

class _MarketScreenState extends State<MarketScreen> {
  final TextEditingController _search = TextEditingController();
  String _query = '';
  String _brandId = MarketTaxonomyIds.anyBrand;
  String _ipId = MarketTaxonomyIds.anyIp;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool get _filtersActive =>
      _brandId != MarketTaxonomyIds.anyBrand || _ipId != MarketTaxonomyIds.anyIp;

  List<MarketListing> _visibleListings() {
    final q = _query.trim().toLowerCase();
    return mockMarketListings
        .where(
          (m) => marketListingVisible(
            m,
            brandId: _brandId,
            ipId: _ipId,
            queryLower: q,
          ),
        )
        .toList(growable: false);
  }

  void _setBrand(String id) {
    setState(() {
      _brandId = id;
      _ipId = MarketTaxonomy.clampIpToBrand(_brandId, _ipId);
    });
  }

  void _setIp(String id) {
    setState(() => _ipId = id);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final filtered = _visibleListings();

    return Scaffold(
      backgroundColor: scheme.surface,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            pinned: false,
            floating: false,
            elevation: 0,
            scrolledUnderElevation: 0,
            toolbarHeight: FeedRhythm.mainTabAppBarToolbarHeight,
            backgroundColor: scheme.surface,
            surfaceTintColor: scheme.surfaceTint.withValues(alpha: 0.32),
            centerTitle: false,
            titleSpacing: 20,
            title: Text(
              'Market',
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w500,
                letterSpacing: -0.22,
                height: 1.18,
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, FeedRhythm.belowMainTabAppBar, 20, 10),
              child: Text(
                'Soft signals for what is moving — visual first, lightweight.',
                style: textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.78),
                  height: 1.42,
                  letterSpacing: 0.02,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                MarketSearchBar(
                  controller: _search,
                  onChanged: (v) => setState(() => _query = v),
                ),
                const SizedBox(height: 16),
                MarketDiscoveryChips(
                  brandOptions: MarketTaxonomy.brandChipOptions(),
                  ipOptions: MarketTaxonomy.ipChipOptionsForBrand(_brandId),
                  brandId: _brandId,
                  ipId: _ipId,
                  onBrandSelected: _setBrand,
                  onIpSelected: _setIp,
                ),
              ],
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.public_rounded,
                    size: 14,
                    color: scheme.onSurfaceVariant.withValues(alpha: 0.42),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Market signals inspired by recent eBay activity',
                      style: textTheme.labelMedium?.copyWith(
                        color: scheme.onSurfaceVariant.withValues(alpha: 0.54),
                        height: 1.42,
                        letterSpacing: 0.04,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 14)),
          SliverToBoxAdapter(
            child: TrendingMarketSection(items: mockTrendingMarketListings()),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 8)),
          SliverToBoxAdapter(
            child: CollectibleSectionHeader(
              title: 'Browse listings',
              showPackagingMark: true,
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 6),
            ),
          ),
          if (filtered.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _MarketEmptySearch(
                query: _query.trim(),
                filterActive: _filtersActive,
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 36),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    return MarketListingCard(listing: filtered[index]);
                  },
                  childCount: filtered.length,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MarketEmptySearch extends StatelessWidget {
  const _MarketEmptySearch({
    required this.query,
    this.filterActive = false,
  });

  final String query;
  final bool filterActive;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final hasQuery = query.isNotEmpty;
    final title = hasQuery
        ? 'No matches for “$query”'
        : filterActive
            ? 'Nothing here for that pick yet'
            : 'No matches';
    final subtitle = hasQuery
        ? 'Try a figure name, series, or brand — or clear the search.'
        : filterActive
            ? 'Try another shelf filter or search the mock catalog.'
            : 'Try another search.';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off_rounded,
            size: 48,
            color: scheme.onSurfaceVariant.withValues(alpha: 0.45),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant.withValues(alpha: 0.9),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
