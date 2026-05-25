import 'dart:async';

import 'package:blindbox_app/features/market/application/collectible_market_providers.dart';
import 'package:blindbox_app/features/market/application/market_browse_notifier.dart';
import 'package:blindbox_app/features/market/application/market_browse_load_more_controller.dart';
import 'package:blindbox_app/features/market/data/gateway/market_gateway_config.dart';
import 'package:blindbox_app/features/market/presentation/collectible_market_display_order.dart';
import 'package:blindbox_app/features/market/presentation/market_price_sort.dart';
import 'package:blindbox_app/features/market/widgets/market_browse_session_transition.dart';
import 'package:blindbox_app/features/market/widgets/collectible_market_card.dart';
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
  final MarketPriceSort _priceSort = MarketPriceSort.lowToHigh;
  List<String> _displayOrderIds = const [];
  MarketPriceSort _displayOrderPriceSort = MarketPriceSort.lowToHigh;
  String? _displayOrderBrowseSignature;

  @override
  void initState() {
    super.initState();
    final draft = ref.read(marketBrowseNotifierProvider).query;
    if (draft.isNotEmpty) {
      _search.text = draft;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_search.text.trim().isNotEmpty) {
        ref.read(marketBrowseNotifierProvider.notifier).setQuery(_search.text);
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  String get _trimmedQuery => _search.text.trim();
  bool get _hasSearchText => _trimmedQuery.isNotEmpty;

  void _onSearchChanged(String value) {
    setState(() {});
    _debounce?.cancel();
    if (value.trim().isEmpty) {
      _exitSearch(clearField: false);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      ref.read(marketBrowseNotifierProvider.notifier).setQuery(value);
    });
  }

  /// Restore Market feed and leave the search overlay route.
  void _exitSearch({bool clearField = true}) {
    _debounce?.cancel();
    if (clearField) _search.clear();
    ref.read(marketBrowseNotifierProvider.notifier).clearSearchSession();
    if (!mounted) return;
    if (context.canPop()) context.pop();
  }

  void _clearSearch() => _exitSearch();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final browse = ref.watch(marketBrowseNotifierProvider);
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
            child: sorted.isEmpty
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
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                      itemCount: sorted.length +
                          (MarketGatewayConfig.isActive && liveHasMore ? 1 : 0),
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
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
