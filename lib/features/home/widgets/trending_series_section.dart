import 'package:blindbox_app/core/layout/feed_rhythm.dart';
import 'package:blindbox_app/core/theme/collectible_shelf_shadow.dart';
import 'package:blindbox_app/core/theme/collectible_tokens.dart';
import 'package:blindbox_app/features/home/data/home_section_zones.dart';
import 'package:blindbox_app/features/home/data/mock_trending_series.dart';
import 'package:blindbox_app/features/home/widgets/trending_series_capsule.dart';
import 'package:blindbox_app/shared/widgets/collectible_section_header.dart';
import 'package:flutter/material.dart';

/// Horizontal IP / series rail — softer and more compact than Latest Drops.
class TrendingSeriesSection extends StatelessWidget {
  const TrendingSeriesSection({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;
    final tokens = CollectibleTokens.of(context);
    final railHeight =
        kTrendingSeriesCapsuleHeight + CollectibleShelfShadow.horizontalRailShellBottomSlack(tokens);

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
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: SizedBox(
              height: railHeight,
              child: ListView.separated(
                clipBehavior: Clip.none,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: mockTrendingSeries.length,
                separatorBuilder: (context, index) =>
                    SizedBox(width: FeedRhythm.horizontalRailCardGap),
                itemBuilder: (context, index) {
                  return Align(
                    alignment: Alignment.topCenter,
                    child: TrendingSeriesCapsule(series: mockTrendingSeries[index]),
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}
