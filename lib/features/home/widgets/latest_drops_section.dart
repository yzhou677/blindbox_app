import 'package:blindbox_app/core/layout/feed_rhythm.dart';
import 'package:blindbox_app/features/home/data/home_drop_rail_context.dart';
import 'package:blindbox_app/features/home/data/home_section_zones.dart';
import 'package:blindbox_app/features/home/widgets/latest_drop_card.dart';
import 'package:blindbox_app/models/collectible.dart';
import 'package:blindbox_app/shared/widgets/collectible_context_chip.dart';
import 'package:blindbox_app/shared/widgets/collectible_section_header.dart';
import 'package:flutter/material.dart';

class LatestDropsSection extends StatelessWidget {
  const LatestDropsSection({super.key, required this.items});

  final List<Collectible> items;

  static const double _railHeight = 428;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;
    final caption = HomeDropRailContext.latestDropsRailCaption(items);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CollectibleSectionHeader(
          title: 'Latest drops',
          trailing: caption == null
              ? null
              : CollectibleContextChip(
                  icon: Icons.schedule_rounded,
                  label: caption,
                  presentation: CollectibleContextPresentation.inlineMeta,
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
                itemCount: items.length,
                separatorBuilder: (context, index) =>
                    SizedBox(width: FeedRhythm.horizontalRailCardGap),
                itemBuilder: (context, index) => LatestDropCard(collectible: items[index]),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
