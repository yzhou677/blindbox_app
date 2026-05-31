import 'package:blindbox_app/core/layout/feed_rhythm.dart';
import 'package:blindbox_app/core/navigation/shell_tab_reselect_bus.dart';
import 'package:blindbox_app/features/market/application/collectible_market_providers.dart';
import 'package:blindbox_app/features/market/debug/market_browse_state_diagnostic.dart';
import 'package:blindbox_app/features/market/debug/market_search_trace.dart';
import 'package:blindbox_app/features/market/application/active_market_browse_query.dart';
import 'package:blindbox_app/features/market/application/market_browse_feed_session_handoff.dart';
import 'package:blindbox_app/features/market/application/market_browse_root_navigation.dart';
import 'package:blindbox_app/features/market/application/market_feed_browse_notifier.dart';
import 'package:blindbox_app/features/market/application/market_search_browse_notifier.dart';
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

  List<String> _displayOrderIds = const [];
  MarketPriceSort _displayOrderPriceSort = MarketPriceSort.lowToHigh;
  String? _displayOrderBrowseSignature;
  String? _lastReconciledRoutePath;
  bool _loggedFirstRootFrameAfterReselect = false;

  @override
  void initState() {
    super.initState();
    ShellTabReselectBus.instance.reselectedBranch.addListener(_onTabReselected);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _consumePendingMarketBrowseRootReselect();
    });
  }

  @override
  void dispose() {
    ShellTabReselectBus.instance.reselectedBranch.removeListener(_onTabReselected);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reconcileSearchSessionWithRoute();
  }

  /// Drops immersive search when the Market root is visible without `/market/search`.
  ///
  /// Covers tab reselect (`goBranch` + `initialLocation`) and other pops that skip
  /// [MarketBrowseSearchScreen._exitSearch]. Provider writes are deferred — this
  /// runs from [didChangeDependencies] during shell navigation rebuilds.
  void _reconcileSearchSessionWithRoute() {
    final path = GoRouterState.of(context).uri.path;
    if (path == _lastReconciledRoutePath) return;
    _lastReconciledRoutePath = path;
    if (!isMarketBrowseRootPath(path)) return;

    final search = ref.read(marketSearchBrowseNotifierProvider);
    final overlayOpen = ref.read(marketSearchOverlayOpenProvider);
    if (!search.isCommitted && !overlayOpen) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final path = GoRouterState.of(context).uri.path;
      if (!isMarketBrowseRootPath(path)) return;
      MarketBrowseStateDiagnostic.log(
        ref,
        phase: 'reconcile_before_clear',
        routePath: path,
      );
      clearMarketSearchOverlaySession(ref);
      beginFeedBrowseSessionHandoff(ref, reason: 'route_reconcile');
      MarketBrowseStateDiagnostic.log(
        ref,
        phase: 'reconcile_after_clear',
        routePath: path,
      );
    });
  }

  void _consumePendingMarketBrowseRootReselect() {
    if (!mounted) return;
    if (!ShellTabReselectBus.instance.takeMarketBrowseRootResetPending()) {
      return;
    }
    completeMarketBrowseRootReselect(ref: ref, context: context);
  }

  void _onTabReselected() {
    if (ShellTabReselectBus.instance.reselectedBranch.value !=
        kMarketShellBranchIndex) {
      return;
    }
    if (!mounted) return;
    completeMarketBrowseRootReselect(ref: ref, context: context);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final feed = ref.watch(marketFeedBrowseNotifierProvider);
    final search = ref.watch(marketSearchBrowseNotifierProvider);
    final overlayOpen = ref.watch(marketSearchOverlayOpenProvider);
    final activeQuery = ref.watch(activeMarketBrowseQueryProvider);
    MarketSearchTrace.event(
      'MarketScreen.build immersive=${overlayOpen && search.isCommitted} '
      'query="${search.query.trim()}"',
    );
    final feedNotifier = ref.read(marketFeedBrowseNotifierProvider.notifier);
    final snapshots = ref.watch(visibleCollectibleMarketSnapshotsProvider);
    final browseSignature = collectibleMarketBrowseSignatureFromQuery(activeQuery);
    final display = resolveCollectibleMarketDisplaySnapshots(
      snapshots: snapshots,
      browseSignature: browseSignature,
      priceSort: feed.priceSort,
      stablePagination: MarketGatewayConfig.isActive,
      sortByPrice: true,
      previousOrderIds: _displayOrderIds,
      previousPriceSort: _displayOrderPriceSort,
      previousBrowseSignature: _displayOrderBrowseSignature,
    );
    final sorted = display.snapshots;
    final immersive = overlayOpen && search.isCommitted;
    final sessionTransitioning = ref.watch(marketBrowseSessionTransitionProvider);
    final feedResults = marketBrowseFeedResultsForDisplay(
      sorted: sorted,
      sessionTransitioning: sessionTransitioning,
      immersive: immersive,
      activeSearchText: activeQuery.searchText,
      gatewayActive: MarketGatewayConfig.isActive,
    );
    final liveHasMore = ref.watch(marketLiveBrowseHasMoreProvider);
    if (display.orderIds != _displayOrderIds ||
        _displayOrderPriceSort != feed.priceSort ||
        _displayOrderBrowseSignature != browseSignature) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _displayOrderIds = display.orderIds;
          _displayOrderPriceSort = feed.priceSort;
          _displayOrderBrowseSignature = browseSignature;
        });
      });
    }
    final loadingMore = ref.watch(marketBrowseLoadMoreProvider);
    final routePath = GoRouterState.of(context).uri.path;
    if (isMarketBrowseRootPath(routePath) && !_loggedFirstRootFrameAfterReselect) {
      _loggedFirstRootFrameAfterReselect = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (!isMarketBrowseRootPath(GoRouterState.of(context).uri.path)) {
          return;
        }
        MarketBrowseStateDiagnostic.log(
          ref,
          phase: 'market_root_first_frame',
          routePath: GoRouterState.of(context).uri.path,
        );
      });
    } else if (!isMarketBrowseRootPath(routePath)) {
      _loggedFirstRootFrameAfterReselect = false;
    }
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
                      ipOptions: MarketTaxonomy.ipChipOptionsForBrand(feed.brandId),
                      brandId: feed.brandId,
                      ipId: feed.ipId,
                      showIpRail: feed.brandId != MarketTaxonomyIds.anyBrand,
                      onBrandSelected: feedNotifier.setBrand,
                      onIpSelected: feedNotifier.setIp,
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
                  onPressed: feedNotifier.togglePriceSort,
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
                    feed.priceSort.browseHeaderLabel,
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
          if (feedResults.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: sessionTransitioning && MarketGatewayConfig.isActive
                  ? const MarketBrowseSliverResultsSkeleton()
                  : _MarketEmptySearch(
                      query: activeQuery.searchText.trim(),
                      filterActive: feed.filtersActive,
                    ),
            )
          else ...[
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                20,
                immersive
                    ? FeedRhythm.blockGapMedium
                    : FeedRhythm.marketBrowseHeaderToFeedGap,
                20,
                FeedRhythm.tabScrollTailPadding,
              ),
              sliver: SliverList.builder(
                itemCount: feedResults.length,
                itemBuilder: (context, i) =>
                    CollectibleMarketCard(snapshot: feedResults[i]),
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
