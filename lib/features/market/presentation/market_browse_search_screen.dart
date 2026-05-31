import 'dart:async';

import 'package:blindbox_app/core/layout/feed_rhythm.dart';
import 'package:blindbox_app/core/navigation/shell_tab_reselect_bus.dart';
import 'package:blindbox_app/core/theme/app_spacing.dart';
import 'package:blindbox_app/features/market/application/collectible_market_providers.dart';
import 'package:blindbox_app/features/market/application/active_market_browse_query.dart';
import 'package:blindbox_app/features/market/application/market_browse_root_navigation.dart';
import 'package:blindbox_app/features/market/application/market_search_browse_notifier.dart';
import 'package:blindbox_app/features/market/application/market_browse_load_more_controller.dart';
import 'package:blindbox_app/features/market/data/gateway/market_gateway_config.dart';
import 'package:blindbox_app/features/market/presentation/collectible_market_display_order.dart';
import 'package:blindbox_app/features/market/presentation/market_price_sort.dart';
import 'package:blindbox_app/features/market/widgets/market_browse_session_transition.dart';
import 'package:blindbox_app/features/market/widgets/collectible_market_card.dart';
import 'package:blindbox_app/features/market/debug/market_browse_state_diagnostic.dart';
import 'package:blindbox_app/features/market/debug/market_search_trace.dart';
import 'package:blindbox_app/features/market/widgets/market_load_more_footer.dart';
import 'package:blindbox_app/shared/widgets/feed_search_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Market tab entry: same full-screen search flow as Discover catalog browse.
class MarketBrowseSearchScreen extends ConsumerStatefulWidget {
  const MarketBrowseSearchScreen({super.key});

  @override
  ConsumerState<MarketBrowseSearchScreen> createState() =>
      _MarketBrowseSearchScreenState();
}

class _MarketBrowseSearchScreenState
    extends ConsumerState<MarketBrowseSearchScreen> {
  final _search = TextEditingController();
  Timer? _debounce;
  List<String> _displayOrderIds = const [];
  String? _displayOrderBrowseSignature;
  String? _lastAuditLoggedSearchSig;

  @override
  void initState() {
    super.initState();
    ShellTabReselectBus.instance.reselectedBranch.addListener(_onTabReselected);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(marketSearchOverlayOpenProvider.notifier).setOpen(true);
      ref.read(marketSearchBrowseNotifierProvider.notifier).beginOverlay();
    });
  }

  @override
  void dispose() {
    ShellTabReselectBus.instance.reselectedBranch.removeListener(_onTabReselected);
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onTabReselected() =>
      handleMarketShellTabReselected(ref: ref, context: context);

  String get _trimmedQuery => _search.text.trim();
  bool get _hasSearchText => _trimmedQuery.isNotEmpty;

  void _onSearchChanged(String value) {
    MarketSearchTrace.event(
      'TextField.onChanged len=${value.length} (local setState)',
    );
    setState(() {});
    _debounce?.cancel();
    if (value.trim().isEmpty) {
      _exitSearch(clearField: false);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      MarketSearchTrace.event('debounce fired → commitQuery "${value.trim()}"');
      ref.read(marketSearchBrowseNotifierProvider.notifier).commitQuery(value);
    });
  }

  /// Restore Market feed and leave the search overlay route.
  void _exitSearch({bool clearField = true}) {
    _debounce?.cancel();
    if (clearField) _search.clear();
    clearMarketSearchOverlaySession(ref);
    if (!mounted) return;
    goToMarketBrowseRoot(context);
  }

  void _clearSearch() => _exitSearch();

  @override
  Widget build(BuildContext context) {
    MarketSearchTrace.event(
      'MarketBrowseSearchScreen.build hasText=$_hasSearchText',
    );
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final search = ref.watch(marketSearchBrowseNotifierProvider);
    final activeQuery = ref.watch(activeMarketBrowseQueryProvider);
    final snapshots = ref.watch(visibleCollectibleMarketSnapshotsProvider);
    final browseSignature = collectibleMarketBrowseSignatureFromQuery(activeQuery);
    final display = resolveCollectibleMarketDisplaySnapshots(
      snapshots: snapshots,
      browseSignature: browseSignature,
      priceSort: MarketPriceSort.lowToHigh,
      stablePagination: MarketGatewayConfig.isActive,
      sortByPrice: false,
      previousOrderIds: _displayOrderIds,
      previousPriceSort: MarketPriceSort.lowToHigh,
      previousBrowseSignature: _displayOrderBrowseSignature,
    );
    final sorted = display.snapshots;
    if (display.orderIds != _displayOrderIds ||
        _displayOrderBrowseSignature != browseSignature) {
      MarketSearchTrace.event(
        'schedule postFrame setState sig=$browseSignature order=${display.orderIds.length}',
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        MarketSearchTrace.event('postFrame setState (display order cache)');
        setState(() {
          _displayOrderIds = display.orderIds;
          _displayOrderBrowseSignature = browseSignature;
        });
      });
    }
    final showResults = search.isCommitted;
    if (showResults &&
        search.query.trim().isNotEmpty &&
        _lastAuditLoggedSearchSig != browseSignature) {
      _lastAuditLoggedSearchSig = browseSignature;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        MarketBrowseStateDiagnostic.log(
          ref,
          phase: 'search_results_after_commit',
          routePath: GoRouterState.of(context).uri.path,
        );
      });
    }
    final liveHasMore = ref.watch(marketLiveBrowseHasMoreProvider);
    final loadingMore = ref.watch(marketBrowseLoadMoreProvider);
    final sessionTransitioning = ref.watch(marketBrowseSessionTransitionProvider);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _exitSearch(clearField: false);
      },
      child: FeedSearchScreen(
      title: 'Search market',
      hintText: 'Search figures, series, brands…',
      emptyPrompt: 'Search by series, figure, or brand.',
      controller: _search,
      hasSearchText: _hasSearchText,
      onChanged: _onSearchChanged,
      onClear: _clearSearch,
      onBack: () => _exitSearch(clearField: false),
      results: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (sessionTransitioning)
            LinearProgressIndicator(
              minHeight: 2,
              color: scheme.primary.withValues(alpha: 0.55),
              backgroundColor: scheme.surfaceContainerHighest,
            ),
          Expanded(
            child: !showResults
                ? const SizedBox.shrink()
                : sorted.isEmpty
                ? sessionTransitioning
                    ? const MarketBrowseResultsSkeleton()
                    : Center(
                        child: Text(
                          'No matches for that search.',
                          style: textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant.withValues(alpha: 0.8),
                          ),
                        ),
                      )
                : MarketBrowseSessionTransition(
                    active: sessionTransitioning,
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.pageHorizontal,
                        AppSpacing.xs,
                        AppSpacing.pageHorizontal,
                        AppSpacing.xxl,
                      ),
                      itemCount: sorted.length +
                          (MarketGatewayConfig.isActive &&
                                  liveHasMore &&
                                  showResults
                              ? 1
                              : 0),
                      // Use the same gap as the main market feed for visual
                      // consistency when results carry over from the browse tab.
                      separatorBuilder: (_, _) => const SizedBox(
                        height: FeedRhythm.marketListingFeedCardVerticalGap,
                      ),
                      itemBuilder: (context, index) {
                        if (index >= sorted.length) {
                          return MarketLoadMoreFooter(
                            loading: loadingMore,
                            onLoadMore: () => ref
                                .read(marketBrowseLoadMoreProvider.notifier)
                                .loadMore(),
                          );
                        }
                        final snapshot = sorted[index];
                        return CollectibleMarketCard(
                          key: ValueKey(snapshot.identity.snapshotId),
                          snapshot: snapshot,
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
      ),
    );
  }
}
