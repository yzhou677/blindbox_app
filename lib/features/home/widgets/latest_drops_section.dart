import 'package:blindbox_app/core/layout/feed_rhythm.dart';
import 'package:blindbox_app/features/home/widgets/latest_drop_card.dart';
import 'package:blindbox_app/models/collectible.dart';
import 'package:blindbox_app/shared/widgets/collectible_section_header.dart';
import 'package:flutter/material.dart';

class LatestDropsSection extends StatelessWidget {
  const LatestDropsSection({super.key, required this.items});

  final List<Collectible> items;

  /// Card + polaroid mat + chip + date pill — tuned for feed balance (not a full-bleed hero).
  static const double _railHeight = 396;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final scheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CollectibleSectionHeader(
          title: 'Latest drops',
          subtitle: 'Fresh picks for your shelf — soft launches, big smiles.',
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
            decoration: BoxDecoration(
              color: scheme.primaryContainer.withValues(alpha: 0.48),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: scheme.primary.withValues(alpha: 0.12),
              ),
            ),
            child: Text(
              'New',
              style: textTheme.labelSmall?.copyWith(
                color: scheme.onPrimaryContainer.withValues(alpha: 0.84),
                fontWeight: FontWeight.w500,
                letterSpacing: 0.08,
                height: 1.1,
              ),
            ),
          ),
        ),
        const SizedBox(height: FeedRhythm.sectionHeaderToRail),
        SizedBox(
          height: _railHeight,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: items.length,
            separatorBuilder: (context, index) => const SizedBox(width: 20),
            itemBuilder: (context, index) => LatestDropCard(collectible: items[index]),
          ),
        ),
      ],
    );
  }
}
