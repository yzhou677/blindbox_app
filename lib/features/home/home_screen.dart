import 'package:blindbox_app/core/layout/feed_rhythm.dart';
import 'package:blindbox_app/features/home/application/home_feed_provider.dart';
import 'package:blindbox_app/features/home/data/home_drop_rail_context.dart';
import 'package:blindbox_app/features/home/data/mock_latest_drops.dart';
import 'package:blindbox_app/features/home/widgets/latest_drops_section.dart';
import 'package:blindbox_app/features/home/widgets/trending_series_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final feedAsync = ref.watch(homeFeedSnapshotProvider);

    return Scaffold(
      backgroundColor: scheme.surfaceContainerLow,
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
            centerTitle: false,
            titleSpacing: 20,
            title: Text('Discover', style: textTheme.titleLarge),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(
                top: FeedRhythm.belowMainTabAppBar,
                bottom: FeedRhythm.tabScrollTailPadding,
              ),
              child: feedAsync.when(
                loading: () => const _HomeFeedLoading(),
                error: (_, __) => _HomeFeedBody(
                  feed: HomeFeedSnapshot(
                    latest: mockSeriesReleases,
                    trending: mockSeriesReleases.skip(1).take(4).toList(growable: false),
                  ),
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
        LatestDropsSection(
          releases: feed.latest,
          trailingCaption: HomeDropRailContext.recentReleasesRailCaption,
        ),
        const SizedBox(height: FeedRhythm.homeMajorSectionGap),
        TrendingSeriesSection(releases: feed.trending),
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
