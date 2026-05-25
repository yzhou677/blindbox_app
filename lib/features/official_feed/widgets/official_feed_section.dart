import 'package:blindbox_app/core/layout/feed_rhythm.dart';
import 'package:blindbox_app/features/home/data/home_section_zones.dart';
import 'package:blindbox_app/features/official_feed/application/official_feed_providers.dart';
import 'package:blindbox_app/features/official_feed/domain/official_feed_item.dart';
import 'package:blindbox_app/features/official_feed/widgets/official_feed_card.dart';
import 'package:blindbox_app/shared/widgets/collectible_section_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Home editorial rail for official drops — hidden when empty or unavailable.
class OfficialFeedSection extends ConsumerWidget {
  const OfficialFeedSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feedAsync = ref.watch(officialFeedListProvider);

    return feedAsync.when(
      data: (items) => _OfficialFeedRail(items: items),
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}

class _OfficialFeedRail extends StatelessWidget {
  const _OfficialFeedRail({required this.items});

  final List<OfficialFeedItem> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const CollectibleSectionHeader(
          title: 'Official drops',
          subtitle: 'News from POP MART',
        ),
        const SizedBox(height: FeedRhythm.sectionHeaderToRail),
        ColoredBox(
          color: HomeSectionZones.officialFeedMat(scheme, brightness),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: SizedBox(
              height: FeedRhythm.homeOfficialFeedRailHeight,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                cacheExtent: FeedRhythm.homeOfficialFeedCardWidth * 2,
                itemCount: items.length,
                separatorBuilder: (context, index) =>
                    SizedBox(width: FeedRhythm.horizontalRailCardGap),
                itemBuilder: (context, index) =>
                    OfficialFeedCard(item: items[index]),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
