import 'package:blindbox_app/core/layout/feed_rhythm.dart';
import 'package:blindbox_app/features/home/data/mock_trending_series.dart';
import 'package:blindbox_app/features/home/widgets/trending_series_capsule.dart';
import 'package:blindbox_app/shared/widgets/collectible_section_header.dart';
import 'package:flutter/material.dart';

/// Horizontal IP / series rail — softer and more compact than Latest Drops.
class TrendingSeriesSection extends StatelessWidget {
  const TrendingSeriesSection({super.key});

  static const double _railHeight = kTrendingSeriesCapsuleHeight + 12;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const CollectibleSectionHeader(
          title: 'Trending series',
          subtitle: 'Browse character worlds and IPs—cozy universe hopping.',
          padding: EdgeInsets.fromLTRB(20, 2, 20, 0),
        ),
        const SizedBox(height: FeedRhythm.sectionHeaderToRail),
        SizedBox(
          height: _railHeight,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: mockTrendingSeries.length,
            separatorBuilder: (context, index) => const SizedBox(width: 14),
            itemBuilder: (context, index) {
              return TrendingSeriesCapsule(series: mockTrendingSeries[index]);
            },
          ),
        ),
      ],
    );
  }
}
