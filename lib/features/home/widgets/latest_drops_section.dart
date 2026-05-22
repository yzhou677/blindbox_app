import 'package:blindbox_app/core/layout/feed_rhythm.dart';
import 'package:blindbox_app/features/home/data/home_drop_rail_context.dart';
import 'package:blindbox_app/features/home/data/home_section_zones.dart';
import 'package:blindbox_app/features/home/domain/series_release.dart';
import 'package:blindbox_app/features/home/widgets/latest_drop_card.dart';
import 'package:flutter/material.dart';
import 'package:blindbox_app/shared/widgets/collectible_section_header.dart';

class LatestDropsSection extends StatelessWidget {
  const LatestDropsSection({
    super.key,
    required this.releases,
    this.trailingCaption,
  });

  final List<SeriesRelease> releases;

  /// When set (e.g. [HomeDropRailContext.recentReleasesRailCaption]), overrides month-based caption.
  final String? trailingCaption;

  static const double _railHeight = 428;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;
    final textTheme = Theme.of(context).textTheme;
    final caption = trailingCaption ??
        HomeDropRailContext.latestDropsRailCaption(
          releases.map((r) => r.heroCollectible),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CollectibleSectionHeader(
          title: 'Latest drops',
          trailing: caption == null
              ? null
              : Semantics(
                  label: 'Release window: $caption',
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.calendar_month_rounded,
                        size: 15,
                        color: scheme.onSurfaceVariant.withValues(alpha: 0.52),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          caption,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.end,
                          style: textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant.withValues(alpha: 0.68),
                            fontWeight: FontWeight.w400,
                            letterSpacing: 0.01,
                            height: 1.2,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
        ),
        const SizedBox(height: FeedRhythm.sectionHeaderToRail),
        ColoredBox(
          color: HomeSectionZones.latestDropsMat(scheme, brightness),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: SizedBox(
              height: _railHeight,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: releases.length,
                separatorBuilder: (context, index) =>
                    SizedBox(width: FeedRhythm.horizontalRailCardGap),
                itemBuilder: (context, index) => LatestDropCard(release: releases[index]),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
