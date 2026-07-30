import 'package:blindbox_app/core/layout/feed_rhythm.dart';
import 'package:blindbox_app/core/theme/app_spacing.dart';
import 'package:blindbox_app/features/official_feed/application/official_feed_providers.dart';
import 'package:blindbox_app/features/official_feed/domain/official_feed_catalog.dart';
import 'package:blindbox_app/features/official_feed/domain/official_feed_item.dart';
import 'package:blindbox_app/features/official_feed/domain/official_feed_sources.dart';
import 'package:blindbox_app/features/official_feed/presentation/official_feed_copy.dart';
import 'package:blindbox_app/features/official_feed/widgets/official_feed_post_tile.dart';
import 'package:blindbox_app/features/official_feed/widgets/official_feed_release_date_note.dart';
import 'package:blindbox_app/shared/widgets/collectible_section_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Official news/announcement feed — below Trending; not the commerce release rail.
class OfficialFeedSection extends ConsumerWidget {
  const OfficialFeedSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalogAsync = ref.watch(officialFeedCatalogProvider);
    final preferred = ref.watch(officialFeedSelectedSourceProvider);

    return catalogAsync.when(
      data: (catalog) {
        final sourceId = OfficialFeedSources.resolveSelection(
          availableSourceIds: catalog.availableSources,
          preferred: preferred,
        );
        if (sourceId == null) return const SizedBox.shrink();
        final items = catalog.itemsFor(sourceId);
        if (items.isEmpty) return const SizedBox.shrink();
        return _OfficialFeedsBody(
          catalog: catalog,
          selectedSourceId: sourceId,
          items: items,
          onSelectSource: (id) {
            ref.read(officialFeedSelectedSourceProvider.notifier).select(id);
          },
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}

class _OfficialFeedsBody extends StatelessWidget {
  const _OfficialFeedsBody({
    required this.catalog,
    required this.selectedSourceId,
    required this.items,
    required this.onSelectSource,
  });

  final OfficialFeedCatalog catalog;
  final String selectedSourceId;
  final List<OfficialFeedItem> items;
  final ValueChanged<String> onSelectSource;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    final showFilters = catalog.showBrandFilters;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CollectibleSectionHeader(
          title: OfficialFeedCopy.sectionTitle,
          subtitle: OfficialFeedCopy.sectionSubtitleFor(selectedSourceId),
        ),
        if (showFilters) ...[
          const SizedBox(height: FeedRhythm.sectionTitleToSubtitle),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.pageHorizontal,
            ),
            child: _OfficialFeedBrandFilters(
              availableSources: catalog.availableSources,
              selectedSourceId: selectedSourceId,
              onSelect: onSelectSource,
            ),
          ),
        ],
        const SizedBox(height: FeedRhythm.sectionTitleToSubtitle),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.pageHorizontal),
          child: OfficialFeedReleaseDateNote(),
        ),
        SizedBox(
          height:
              FeedRhythm.sectionHeaderToRail -
              FeedRhythm.sectionTitleToSubtitle,
        ),
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

class _OfficialFeedBrandFilters extends StatelessWidget {
  const _OfficialFeedBrandFilters({
    required this.availableSources,
    required this.selectedSourceId,
    required this.onSelect,
  });

  final List<String> availableSources;
  final String selectedSourceId;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      key: const Key('official_feed_brand_filters'),
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var i = 0; i < availableSources.length; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            _OfficialFeedBrandChip(
              sourceId: availableSources[i],
              selected: selectedSourceId == availableSources[i],
              onSelect: onSelect,
              scheme: scheme,
            ),
          ],
        ],
      ),
    );
  }
}

class _OfficialFeedBrandChip extends StatelessWidget {
  const _OfficialFeedBrandChip({
    required this.sourceId,
    required this.selected,
    required this.onSelect,
    required this.scheme,
  });

  final String sourceId;
  final bool selected;
  final ValueChanged<String> onSelect;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    final label = OfficialFeedSources.displayLabel(sourceId);
    return Material(
      color: selected
          ? scheme.primary.withValues(alpha: 0.14)
          : scheme.surfaceContainerHighest.withValues(alpha: 0.55),
      shape: StadiumBorder(
        side: BorderSide(
          color: selected
              ? scheme.primary.withValues(alpha: 0.42)
              : scheme.outlineVariant.withValues(alpha: 0.35),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: Key('official_feed_brand_$sourceId'),
        onTap: () => onSelect(sourceId),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              fontSize: 13,
              height: 1.15,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected
                  ? scheme.primary
                  : scheme.onSurface.withValues(alpha: 0.72),
            ),
          ),
        ),
      ),
    );
  }
}
