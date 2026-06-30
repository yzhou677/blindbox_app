import 'package:blindbox_app/core/layout/feed_rhythm.dart';
import 'package:blindbox_app/features/catalog/application/catalog_availability.dart';
import 'package:blindbox_app/features/catalog/widgets/catalog_availability_card.dart';
import 'package:blindbox_app/features/home/application/home_feed_provider.dart';
import 'package:blindbox_app/features/home/data/home_section_zones.dart';
import 'package:blindbox_app/features/home/presentation/latest_drops_copy.dart';
import 'package:blindbox_app/features/home/widgets/latest_drops_section.dart';
import 'package:blindbox_app/features/home/widgets/trending_series_section.dart';
import 'package:blindbox_app/shared/widgets/collectible_section_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Latest + Trending catalog rails with explicit loading / offline states.
class HomeCatalogRails extends ConsumerWidget {
  const HomeCatalogRails({super.key, required this.feed});

  final HomeFeedSnapshot feed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final availability = ref.watch(catalogAvailabilityProvider);
    final retry = ref.read(catalogDownloadRetryProvider);

    if (availability.isCatalogUsable) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LatestDropsSection(releases: feed.latest),
          const SizedBox(height: FeedRhythm.homeMajorSectionGap),
          TrendingSeriesSection(releases: feed.trending),
        ],
      );
    }

    final scheme = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const CollectibleSectionHeader(
          title: LatestDropsCopy.sectionTitle,
          subtitle: LatestDropsCopy.sectionSubtitle,
        ),
        const SizedBox(height: FeedRhythm.sectionHeaderToRail),
        ColoredBox(
          color: HomeSectionZones.latestDropsMat(scheme, brightness),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 0),
            child: CatalogAvailabilityCard(
              availability: availability,
              onRetry: availability.isOfflineFirstLaunch ? retry : null,
            ),
          ),
        ),
        const SizedBox(height: FeedRhythm.homeMajorSectionGap),
        const CollectibleSectionHeader(
          title: 'Trending series',
          padding: EdgeInsets.fromLTRB(20, 2, 20, 0),
        ),
        const SizedBox(height: FeedRhythm.sectionHeaderToRail),
        ColoredBox(
          color: HomeSectionZones.trendingSeriesMat(scheme, brightness),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 18),
            child: CatalogAvailabilityCard(
              availability: availability,
              onRetry: availability.isOfflineFirstLaunch ? retry : null,
            ),
          ),
        ),
      ],
    );
  }
}
