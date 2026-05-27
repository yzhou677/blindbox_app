import 'package:blindbox_app/core/layout/feed_rhythm.dart';
import 'package:blindbox_app/core/navigation/shell_tab_reselect_bus.dart';
import 'package:blindbox_app/features/market/application/collectible_market_providers.dart';
import 'package:blindbox_app/features/market/application/market_browse_notifier.dart';
import 'package:blindbox_app/features/market/application/market_browse_load_more_controller.dart';
import 'package:blindbox_app/features/market/application/market_browse_refresh_controller.dart';
import 'package:blindbox_app/features/market/data/gateway/market_gateway_config.dart';
import 'package:blindbox_app/features/market/data/sandbox/market_sandbox_config.dart';
import 'package:blindbox_app/features/market/widgets/market_load_more_footer.dart';
import 'package:blindbox_app/features/market/catalog/market_taxonomy.dart';
import 'package:blindbox_app/features/market/data/mock_market_listings.dart';
import 'package:blindbox_app/features/market/presentation/collectible_market_display_order.dart';
import 'package:blindbox_app/features/market/presentation/market_price_sort.dart';
import 'package:blindbox_app/features/market/widgets/collectible_market_card.dart';
import 'package:blindbox_app/features/market/widgets/market_browse_session_transition.dart';
import 'package:blindbox_app/features/market/widgets/market_discovery_chips.dart';
import 'package:blindbox_app/features/market/application/chasers_phase1_scorer.dart';
import 'package:blindbox_app/features/market/application/market_chasers_controller.dart';
import 'package:blindbox_app/features/market/data/chasers/market_chasers_config.dart';
import 'package:blindbox_app/features/market/widgets/chasers_market_section.dart';
import 'package:blindbox_app/features/market/widgets/market_data_source_notice.dart';
import 'package:blindbox_app/shared/widgets/app_search_field.dart';
import 'package:blindbox_app/shared/widgets/collectible_section_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class MarketScreen extends ConsumerStatefulWidget {
  const MarketScreen({super.key});

  @override
  ConsumerState<MarketScreen> createState() => _MarketScreenState();
}

class _MarketScreenState extends ConsumerState<MarketScreen> {
  final ScrollController _scrollController = ScrollController();

  /// Presentation-only; browse list is derived from filters + this order.
  MarketPriceSort _priceSort = MarketPriceSort.lowToHigh;
  List<String> _displayOrderIds = const [];
  MarketPriceSort _displayOrderPriceSort = MarketPriceSort.lowToHigh;
  String? _displayOrderBrowseSignature;

  @override
  void initState() {
    super.initState();
    ShellTabReselectBus.instance.reselectedBranch.addListener(_onTabReselected);
  }

  @override
  void dispose() {
    ShellTabReselectBus.instance.reselectedBranch.removeListener(_onTabReselected);
    _scrollController.dispose();
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

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final browse = ref.watch(marketBrowseNotifierProvider);
    final notifier = ref.read(marketBrowseNotifierProvider.notifier);
    final snapshots = ref.watch(visibleCollectibleMarketSnapshotsProvider);
    final browseSignature = collectibleMarketBrowseSignature(
      brandId: browse.brandId,
      ipId: browse.ipId,
      query: browse.query.trim(),
      searchResultsActive: browse.searchResultsActive,
    );
    final display = resolveCollectibleMarketDisplaySnapshots(
      snapshots: snapshots,
      browseSignature: browseSignature,
      priceSort: _priceSort,
      stablePagination: MarketGatewayConfig.isActive,
      previousOrderIds: _displayOrderIds,
      previousPriceSort: _displayOrderPriceSort,
      previousBrowseSignature: _displayOrderBrowseSignature,
    );
    final sorted = display.snapshots;
    if (display.orderIds != _displayOrderIds ||
        _displayOrderPriceSort != _priceSort ||
        _displayOrderBrowseSignature != browseSignature) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _displayOrderIds = display.orderIds;
          _displayOrderPriceSort = _priceSort;
          _displayOrderBrowseSignature = browseSignature;
        });
      });
    }
    final immersive = browse.searchResultsActive;
    final liveHasMore = ref.watch(marketLiveBrowseHasMoreProvider);
    final loadingMore = ref.watch(marketBrowseLoadMoreProvider);
    final sessionTransitioning = ref.watch(marketBrowseSessionTransitionProvider);
    final chasersState = ref.watch(marketChasersControllerProvider);
    final showLiveChasersSlot = MarketChasersConfig.showLiveChasersSlot(
      isLoading: chasersState.isLoading,
      entryCount: chasersState.entries.length,
    );
    final showFixtureChasers = MarketChasersConfig.showFixtureRail;

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
                  AppSearchField(
                    readOnly: true,
                    onTap: () => context.push('/market/search'),
                    hintText: 'Search figures, series, brands…',
                  ),
                  if (!immersive) ...[
                    const SizedBox(height: FeedRhythm.blockGapMedium),
                    const MarketDataSourceNotice(),
                  ],
                  if (!immersive && showLiveChasersSlot) ...[
                    const SizedBox(height: FeedRhythm.blockGapMedium),
                    ChasersMarketSection(
                      entries: chasersState.entries,
                      isLoading: chasersState.isLoading,
                    ),
                    const SizedBox(height: FeedRhythm.marketChasersToBrowseHeaderGap),
                  ],
                  if (!immersive && showFixtureChasers) ...[
                    const SizedBox(height: FeedRhythm.blockGapMedium),
                    ChasersMarketSection(
                      entries: chasersHeatFromFixtureListings(mockChasersMarketListings()),
                    ),
                    const SizedBox(height: FeedRhythm.marketChasersToBrowseHeaderGap),
                  ],
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
          if (!immersive &&
              !MarketGatewayConfig.isActive &&
              !showFixtureChasers &&
              !showLiveChasersSlot)
            const SliverToBoxAdapter(child: SizedBox(height: FeedRhythm.blockGapMedium)),
          if (!immersive) ...[
            if (MarketGatewayConfig.isActive)
              const SliverToBoxAdapter(child: SizedBox(height: FeedRhythm.blockGapMedium)),
            SliverToBoxAdapter(
              child: CollectibleSectionHeader(
                title: 'Collectibles',
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
              child: sessionTransitioning && MarketGatewayConfig.isActive
                  ? const MarketBrowseResultsSkeleton()
                  : _MarketEmptySearch(
                      query: browse.query.trim(),
                      filterActive: browse.filtersActive,
                    ),
            )
          else ...[
            // Session-transition loading indicator floats above the list as a
            // separate sliver so the card list below can remain lazy.
            if (sessionTransitioning)
              const SliverToBoxAdapter(
                child: _MarketSessionTransitionIndicator(),
              ),
            // Lazy card list: only visible cards are built and laid out.
            // SliverOpacity dims stale results while a new session loads,
            // matching the previous MarketBrowseSessionTransition behaviour.
            SliverOpacity(
              opacity: sessionTransitioning ? 0.34 : 1.0,
              sliver: SliverIgnorePointer(
                ignoring: sessionTransitioning,
                sliver: SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    20,
                    immersive
                        ? FeedRhythm.blockGapMedium
                        : FeedRhythm.marketBrowseHeaderToFeedGap,
                    20,
                    FeedRhythm.tabScrollTailPadding,
                  ),
                  sliver: SliverList.builder(
                    itemCount: sorted.length,
                    itemBuilder: (context, i) =>
                        CollectibleMarketCard(snapshot: sorted[i]),
                  ),
                ),
              ),
            ),
          ],
          if ((MarketGatewayConfig.isActive || MarketSandboxConfig.isActive) &&
              liveHasMore &&
              !immersive)
            SliverToBoxAdapter(
              child: MarketLoadMoreFooter(
                loading: loadingMore,
                onLoadMore: () => ref
                    .read(marketBrowseLoadMoreProvider.notifier)
                    .loadMore(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact loading pill shown while a new browse session loads (live gateway).
///
/// Rendered as a separate sliver above the dimmed card list so that the list
/// can remain a lazy [SliverList] without needing an animated wrapper.
class _MarketSessionTransitionIndicator extends StatelessWidget {
  const _MarketSessionTransitionIndicator();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: scheme.surface.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: 0.45),
            ),
            boxShadow: [
              BoxShadow(
                color: scheme.shadow.withValues(alpha: 0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: scheme.primary.withValues(alpha: 0.72),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Updating listings',
                  style: textTheme.labelMedium?.copyWith(
                    color: scheme.onSurfaceVariant.withValues(alpha: 0.82),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
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
