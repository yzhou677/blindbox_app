import 'package:blindbox_app/core/layout/feed_rhythm.dart';
import 'package:blindbox_app/features/home/data/home_section_zones.dart';
import 'package:blindbox_app/features/home/domain/series_release.dart';
import 'package:blindbox_app/features/home/widgets/latest_drop_card.dart';
import 'package:blindbox_app/shared/widgets/collectible_section_header.dart';
import 'package:flutter/material.dart';

/// Trending series rail — same card language as Latest Drops.
class TrendingSeriesSection extends StatelessWidget {
  const TrendingSeriesSection({super.key, required this.releases});

  final List<SeriesRelease> releases;


  @override
  Widget build(BuildContext context) {
    if (releases.isEmpty) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const CollectibleSectionHeader(
          title: 'Trending series',
          padding: EdgeInsets.fromLTRB(20, 2, 20, 0),
        ),
        const SizedBox(height: FeedRhythm.sectionHeaderToRail),
        ColoredBox(
          color: HomeSectionZones.trendingSeriesMat(scheme, brightness),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 18),
            child: SizedBox(
              height: FeedRhythm.homeSeriesRailHeight,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: releases.length,
                separatorBuilder: (context, index) =>
                    SizedBox(width: FeedRhythm.horizontalRailCardGap),
                itemBuilder: (context, index) =>
                    LatestDropCard(release: releases[index]),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
