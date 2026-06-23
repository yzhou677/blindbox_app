import 'package:blindbox_app/core/layout/feed_rhythm.dart';
import 'package:blindbox_app/core/theme/collectible_motion.dart';
import 'package:blindbox_app/core/navigation/shell_tab_reselect_bus.dart';
import 'package:blindbox_app/features/home/application/home_feed_provider.dart';
import 'package:blindbox_app/features/home/widgets/latest_drops_section.dart';
import 'package:blindbox_app/features/home/widgets/trending_series_section.dart';
import 'package:blindbox_app/features/official_feed/widgets/official_feed_section.dart';
import 'package:blindbox_app/shared/widgets/app_search_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final ScrollController _scrollController = ScrollController();

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
    if (ShellTabReselectBus.instance.reselectedBranch.value != kHomeShellBranchIndex) {
      return;
    }
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      0,
      duration: CollectibleMotion.sheet,
      curve: CollectibleMotion.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final feedAsync = ref.watch(homeFeedSnapshotProvider);

    return Scaffold(
      backgroundColor: scheme.surfaceContainerLow,
      body: CustomScrollView(
        controller: _scrollController,
        physics: const BouncingScrollPhysics(),
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
            title: Text('Discover', style: textTheme.titleLarge),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: FeedRhythm.headerToSearchField),
              child: AppSearchField(
                readOnly: true,
                onTap: () => context.push('/home/catalog'),
                hintText: 'Search catalog — figures, series, IPs…',
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(
                top: FeedRhythm.homeSearchToFirstSection,
                bottom: FeedRhythm.tabScrollTailPadding,
              ),
              child: feedAsync.when(
                loading: () => const _HomeFeedLoading(),
                error: (_, _) => const _HomeFeedBody(
                  feed: HomeFeedSnapshot(latest: [], trending: []),
                ),
                data: (feed) => _HomeFeedBody(feed: feed),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeFeedBody extends StatelessWidget {
  const _HomeFeedBody({required this.feed});

  final HomeFeedSnapshot feed;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LatestDropsSection(releases: feed.latest),
        const SizedBox(height: FeedRhythm.homeMajorSectionGap),
        TrendingSeriesSection(releases: feed.trending),
        const SizedBox(height: FeedRhythm.homeMajorSectionGap),
        const OfficialFeedSection(),
      ],
    );
  }
}

class _HomeFeedLoading extends StatelessWidget {
  const _HomeFeedLoading();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(height: 200, child: Center(child: CircularProgressIndicator())),
        SizedBox(height: FeedRhythm.homeMajorSectionGap),
        SizedBox(height: 200),
      ],
    );
  }
}
