import 'package:blindbox_app/core/layout/feed_rhythm.dart';
import 'package:blindbox_app/features/official_feed/application/official_feed_providers.dart';
import 'package:blindbox_app/features/official_feed/domain/official_feed_item.dart';
import 'package:blindbox_app/features/official_feed/widgets/official_feed_post_tile.dart';
import 'package:blindbox_app/shared/widgets/collectible_section_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Home compact official updates feed — below Trending, hidden when empty.
class OfficialFeedSection extends ConsumerWidget {
  const OfficialFeedSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feedAsync = ref.watch(officialFeedListProvider);

    return feedAsync.when(
      data: (items) => _OfficialUpdatesFeed(items: items),
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}

class _OfficialUpdatesFeed extends StatelessWidget {
  const _OfficialUpdatesFeed({required this.items});

  final List<OfficialFeedItem> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const CollectibleSectionHeader(
          title: 'Official updates',
          subtitle: 'Verified posts from POP MART',
        ),
        const SizedBox(height: FeedRhythm.sectionHeaderToRail),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              for (var i = 0; i < items.length; i++) ...[
                if (i > 0) SizedBox(height: FeedRhythm.homeOfficialFeedPostGap),
                OfficialFeedPostTile(item: items[i]),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
