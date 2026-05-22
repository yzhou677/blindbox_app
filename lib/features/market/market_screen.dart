import 'package:blindbox_app/core/layout/feed_rhythm.dart';
import 'package:blindbox_app/core/navigation/shell_tab_reselect_bus.dart';
import 'package:blindbox_app/features/market/application/market_browse_notifier.dart';
import 'package:blindbox_app/features/market/application/market_browse_refresh_controller.dart';
import 'package:blindbox_app/features/market/application/market_listings_providers.dart';
import 'package:blindbox_app/features/market/catalog/market_listing_filters.dart';
import 'package:blindbox_app/features/market/catalog/market_taxonomy.dart';
import 'package:blindbox_app/features/market/data/mock_market_listings.dart';
import 'package:blindbox_app/features/market/presentation/market_price_sort.dart';
import 'package:blindbox_app/features/market/widgets/market_discovery_chips.dart';
import 'package:blindbox_app/features/market/widgets/market_listing_card.dart';
import 'package:blindbox_app/features/market/widgets/market_search_bar.dart';
import 'package:blindbox_app/features/market/widgets/trending_market_section.dart';
import 'package:blindbox_app/models/market_listing.dart';
import 'package:blindbox_app/shared/widgets/collectible_section_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class MarketScreen extends ConsumerStatefulWidget {
  const MarketScreen({super.key});

  @override
  ConsumerState<MarketScreen> createState() => _MarketScreenState();
}

class _MarketScreenState extends ConsumerState<MarketScreen> {
  final TextEditingController _search = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  /// Presentation-only; browse list is derived from filters + this order.
  MarketPriceSort _priceSort = MarketPriceSort.lowToHigh;

  @override
  void initState() {
    super.initState();
    ShellTabReselectBus.instance.reselectedBranch.addListener(_onTabReselected);
  }

  @override
  void dispose() {
    ShellTabReselectBus.instance.reselectedBranch.removeListener(_onTabReselected);
    _scrollController.dispose();
    _search.dispose();
    super.dispose();
  }

  void _onTabReselected() {
    if (ShellTabReselectBus.instance.reselectedBranch.value !=
        kMarketShellBranchIndex) {
      return;
    }
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  void _clearDraft() {
    _search.clear();
    ref.read(marketBrowseNotifierProvider.notifier).setQuery('');
  }

  void _clearSearchSession() {
    FocusManager.instance.primaryFocus?.unfocus();
    _search.clear();
    ref.read(marketBrowseNotifierProvider.notifier).clearSearchSession();
  }

  List<MarketListing> _visibleListings(MarketBrowseState browse, List<MarketListing> all) {
    final q = browse.query.trim().toLowerCase();
    return all
        .where(
          (m) => marketListingVisible(
            m,
            brandId: browse.brandId,
            ipId: browse.ipId,
            queryLower: q,
          ),
        )
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final browse = ref.watch(marketBrowseNotifierProvider);
    final notifier = ref.read(marketBrowseNotifierProvider.notifier);
    final allListings = ref.watch(marketBrowseListingsProvider);
    final filtered = _visibleListings(browse, allListings);
    final sorted = marketListingsSortedByPrice(filtered, _priceSort);
    final immersive = browse.searchResultsActive;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: RefreshIndicator(
        onRefresh: () =>
            ref.read(marketBrowseRefreshProvider.notifier).refresh(),
        child: CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
          SliverAppBar(
            pinned: false,
            floating: false,
            elevation: 0,
            scrolledUnderElevation: 0,
            toolbarHeight: FeedRhythm.mainTabAppBarToolbarHeight,
            backgroundColor: scheme.surface,
            centerTitle: false,
            titleSpacing: 20,
            title: Text('Market', style: textTheme.titleLarge),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: FeedRhythm.headerToSearchField),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  MarketSearchBar(
                    controller: _search,
                    onChanged: notifier.setQuery,
                    onSearchSubmitted: notifier.submitSearch,
                    onClearSearchSession: _clearSearchSession,
                    onClearDraft: _clearDraft,
                    searchResultsActive: browse.searchResultsActive,
                    showClearDraft: browse.query.trim().isNotEmpty && !browse.searchResultsActive,
                  ),
                  if (!immersive) ...[
                    const SizedBox(height: FeedRhythm.blockGapMedium),
                    MarketDiscoveryChips(
                      brandOptions: MarketTaxonomy.brandChipOptions(),
                      ipOptions: MarketTaxonomy.ipChipOptionsForBrand(browse.brandId),
                      brandId: browse.brandId,
                      ipId: browse.ipId,
                      showIpRail: browse.brandId != MarketTaxonomyIds.anyBrand,
                      onBrandSelected: notifier.setBrand,
                      onIpSelected: notifier.setIp,
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (!immersive) ...[
            const SliverToBoxAdapter(child: SizedBox(height: FeedRhythm.blockGapMedium)),
            SliverToBoxAdapter(
              child: TrendingMarketSection(items: mockTrendingMarketListings()),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: FeedRhythm.marketTrendingToBrowseHeaderGap)),
            SliverToBoxAdapter(
              child: CollectibleSectionHeader(
                title: 'Listings',
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                trailing: TextButton(
                  key: const Key('market_browse_price_sort'),
                  onPressed: () {
                    setState(() {
                      _priceSort = _priceSort == MarketPriceSort.lowToHigh
                          ? MarketPriceSort.highToLow
                          : MarketPriceSort.lowToHigh;
                    });
                  },
                  style: TextButton.styleFrom(
                    backgroundColor: Color.lerp(
                      scheme.surface,
                      scheme.primaryContainer,
                      0.32,
                    )!.withValues(alpha: 0.92),
                    foregroundColor: scheme.primary.withValues(alpha: 0.78),
                    shadowColor: Colors.transparent,
                    surfaceTintColor: Colors.transparent,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    minimumSize: const Size(48, 40),
                    tapTargetSize: MaterialTapTargetSize.padded,
                    visualDensity: VisualDensity.compact,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    _priceSort.browseHeaderLabel,
                    style: textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.02,
                      height: 1.1,
                      color: scheme.primary.withValues(alpha: 0.78),
                    ),
                  ),
                ),
              ),
            ),
          ],
          if (sorted.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _MarketEmptySearch(
                query: browse.query.trim(),
                filterActive: browse.filtersActive,
              ),
            )
          else
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                20,
                immersive
                    ? FeedRhythm.blockGapMedium
                    : FeedRhythm.marketBrowseHeaderToFeedGap,
                20,
                FeedRhythm.tabScrollTailPadding,
              ),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    return MarketListingCard(listing: sorted[index]);
                  },
                  childCount: sorted.length,
                ),
              ),
            ),
          ],
        ),
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
        ? 'No matches'
        : filterActive
            ? 'Nothing here'
            : 'No matches';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off_rounded,
            size: 48,
            color: scheme.onSurfaceVariant.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: scheme.onSurfaceVariant.withValues(alpha: 0.78),
            ),
          ),
        ],
      ),
    );
  }
}
