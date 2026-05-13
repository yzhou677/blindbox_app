import 'package:blindbox_app/features/market/data/mock_market_listings.dart';
import 'package:blindbox_app/features/market/utils/market_filter_match.dart';
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
  String _filterId = 'all';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<MarketListing> _visibleListings() {
    final byFilter = _filterId == 'all'
        ? mockMarketListings
        : mockMarketListings.where((m) => marketListingMatchesFilter(m, _filterId)).toList(growable: false);

    final t = _query.trim().toLowerCase();
    if (t.isEmpty) return byFilter;
    return byFilter.where((m) {
      final c = m.collectible;
      return c.name.toLowerCase().contains(t) ||
          c.series.toLowerCase().contains(t) ||
          c.brand.toLowerCase().contains(t);
    }).toList(growable: false);
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
            toolbarHeight: 52,
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
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
              child: Text(
                'Soft signals for what is moving — visual first, lightweight.',
                style: textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.82),
                  height: 1.38,
                  letterSpacing: 0.08,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: MarketDiscoveryChips(
              selectedId: _filterId,
              onSelected: (id) => setState(() => _filterId = id),
            ),
          ),
          SliverToBoxAdapter(
            child: MarketSearchBar(
              controller: _search,
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          SliverToBoxAdapter(
            child: TrendingMarketSection(items: mockTrendingMarketListings()),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: Text(
                'Browse listings',
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                  letterSpacing: -0.12,
                  height: 1.22,
                ),
              ),
            ),
          ),
          if (filtered.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _MarketEmptySearch(
                query: _query.trim(),
                filterActive: _filterId != 'all',
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
