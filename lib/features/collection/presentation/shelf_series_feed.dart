import 'package:blindbox_app/core/layout/feed_rhythm.dart';
import 'package:blindbox_app/features/collection/application/series_completion_atmosphere.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/collection/domain/series_completion_atmosphere.dart';
import 'package:blindbox_app/features/collection/domain/shelf_emotional_profile.dart';
import 'package:blindbox_app/features/collection/widgets/series_shelf_cards.dart';
import 'package:blindbox_app/shared/widgets/collectible_section_header.dart';
import 'package:flutter/material.dart';

/// Stable universe key for shelf grouping — avoids empty keys merging unrelated rows.
String shelfIpGroupKey(ShelfSeries series) {
  final taxId = series.taxonomyIpId?.trim();
  if (taxId != null && taxId.isNotEmpty) return 'ip:$taxId';
  final ip = shelfSeriesIpLabel(series).trim();
  if (ip.isNotEmpty) return 'ip:${ip.toLowerCase()}';
  final brand = series.brand.trim();
  if (brand.isNotEmpty) return 'brand:${brand.toLowerCase()}';
  return 'series:${series.id}';
}

/// One universe section on the shelf feed.
@immutable
class ShelfUniverseSection {
  const ShelfUniverseSection({
    required this.key,
    required this.label,
    required this.series,
  });

  final String key;
  final String label;
  final List<ShelfSeries> series;
}

List<ShelfUniverseSection> groupShelfSeriesByUniverse(List<ShelfSeries> series) {
  if (series.isEmpty) return const [];

  final buckets = <String, List<ShelfSeries>>{};
  final order = <String>[];

  for (final row in series) {
    final key = shelfIpGroupKey(row);
    if (!buckets.containsKey(key)) {
      order.add(key);
      buckets[key] = [];
    }
    buckets[key]!.add(row);
  }

  return [
    for (final key in order)
      ShelfUniverseSection(
        key: key,
        label: _universeLabelFor(buckets[key]!.first, key),
        series: buckets[key]!,
      ),
  ];
}

String _universeLabelFor(ShelfSeries first, String key) {
  if (key.startsWith('series:')) return first.name;
  final ip = shelfSeriesIpLabel(first).trim();
  if (ip.isNotEmpty) return ip;
  final brand = first.brand.trim();
  if (brand.isNotEmpty) return brand;
  return first.name;
}

/// Whether this universe block gets an explicit section header.
bool shouldShowShelfUniverseHeader({
  required int universeCount,
  required int seriesInUniverse,
}) {
  if (universeCount > 1) return true;
  return seriesInUniverse >= 2;
}

// ---------------------------------------------------------------------------
// Lazy-list data model
// ---------------------------------------------------------------------------

/// A single flat entry in the shelf's lazy [SliverList] feed.
///
/// Produced by [buildShelfFeedItems]; consumed by a [SliverList.builder] so
/// that off-screen cards are never built or laid out.
sealed class ShelfFeedItem {
  const ShelfFeedItem({required this.sectionColor});

  /// Background colour of this item's section plane — isolates card shadows.
  final Color sectionColor;
}

/// Section header row (universe label + spacing).
final class ShelfFeedHeader extends ShelfFeedItem {
  const ShelfFeedHeader({
    required super.sectionColor,
    required this.sectionKey,
    required this.label,
    required this.topPadding,
  });

  final String sectionKey;
  final String label;
  final double topPadding;
}

/// Inter-section spacing row without a header label.
final class ShelfFeedGap extends ShelfFeedItem {
  const ShelfFeedGap({required super.sectionColor, required this.height});
  final double height;
}

/// One series card row.
final class ShelfFeedCard extends ShelfFeedItem {
  const ShelfFeedCard({
    required super.sectionColor,
    required this.series,
    required this.progress,
    required this.figureStates,
    required this.atmosphere,
  });

  final ShelfSeries series;
  final SeriesProgressCounts progress;
  final Map<String, TrackedFigure> figureStates;
  final SeriesCompletionAtmosphere atmosphere;
}

/// Returns a flat list of [ShelfFeedItem]s that drives a [SliverList.builder].
///
/// The list preserves identical section grouping, spacing, and header-visibility
/// logic as [buildShelfSeriesFeed] while decoupling data computation from widget
/// construction so callers can render only visible items.
List<ShelfFeedItem> buildShelfFeedItems({
  required BuildContext context,
  required List<ShelfSeries> series,
  required Map<String, TrackedFigure> figureStates,
  ShelfEmotionalProfile? profile,
}) {
  if (series.isEmpty) return const [];

  final shelfHarmony =
      profile?.themeIncludes(ShelfEditorialTheme.harmony) ?? false;
  final sections = groupShelfSeriesByUniverse(series);
  final universeCount = sections.length;
  final sectionColor = Theme.of(context).scaffoldBackgroundColor;

  final items = <ShelfFeedItem>[];
  for (var i = 0; i < sections.length; i++) {
    final section = sections[i];
    final showHeader = shouldShowShelfUniverseHeader(
      universeCount: universeCount,
      seriesInUniverse: section.series.length,
    );

    if (showHeader) {
      items.add(ShelfFeedHeader(
        sectionColor: sectionColor,
        sectionKey: section.key,
        label: section.label,
        topPadding: i == 0
            ? FeedRhythm.collectionUniverseSectionTop
            : FeedRhythm.collectionUniverseSectionGap,
      ));
    } else if (i > 0) {
      items.add(ShelfFeedGap(
        sectionColor: sectionColor,
        height: FeedRhythm.collectionUniverseSectionGap,
      ));
    }

    for (final s in section.series) {
      items.add(ShelfFeedCard(
        sectionColor: sectionColor,
        series: s,
        progress: progressForSeries(s, figureStates),
        figureStates: figureStates,
        atmosphere: atmosphereForSeries(
          s,
          figureStates,
          shelfHarmony: shelfHarmony,
        ),
      ));
    }
  }
  return items;
}

/// Builds the widget for a single [ShelfFeedItem] within a [SliverList.builder].
///
/// Wraps each item in a [ColoredBox] matching its section plane so that card
/// shadows don't bleed through translucent gaps between adjacent sections.
Widget buildShelfFeedItemWidget(
  ShelfFeedItem item, {
  required void Function(ShelfSeries) onOpen,
  required void Function(ShelfSeries) onRemove,
}) {
  return switch (item) {
    ShelfFeedHeader(:final sectionColor, :final label, :final topPadding) =>
      ColoredBox(
        color: sectionColor,
        child: Padding(
          padding: EdgeInsets.only(
            top: topPadding,
            bottom: FeedRhythm.collectionUniverseHeaderToCards,
          ),
          child: CollectibleSectionHeader(title: label, padding: EdgeInsets.zero),
        ),
      ),
    ShelfFeedGap(:final sectionColor, :final height) =>
      ColoredBox(color: sectionColor, child: SizedBox(height: height)),
    ShelfFeedCard(
      :final sectionColor,
      :final series,
      :final progress,
      :final figureStates,
      :final atmosphere,
    ) =>
      ColoredBox(
        color: sectionColor,
        child: SeriesShelfCard(
          key: ValueKey(series.id),
          series: series,
          progress: progress,
          figureStates: figureStates,
          atmosphere: atmosphere,
          onOpen: () => onOpen(series),
          onRemove: () => onRemove(series),
        ),
      ),
  };
}

// ---------------------------------------------------------------------------
// Legacy eager builder — kept for backward compatibility with existing callers.
// For new code prefer [buildShelfFeedItems] + [SliverList.builder].
// ---------------------------------------------------------------------------

/// Builds shelf series cards with explicit universe section ownership.
///
/// Each universe block sits on an opaque scaffold-colored plane so scroll does
/// not stack card shadows into translucent horizontal bands between sections.
List<Widget> buildShelfSeriesFeed({
  required BuildContext context,
  required List<ShelfSeries> series,
  required Map<String, TrackedFigure> figureStates,
  required void Function(ShelfSeries series) onOpen,
  required void Function(ShelfSeries series) onRemove,
  ShelfEmotionalProfile? profile,
}) {
  if (series.isEmpty) return const [];

  final shelfHarmony = profile?.themeIncludes(ShelfEditorialTheme.harmony) ?? false;
  final sections = groupShelfSeriesByUniverse(series);
  final universeCount = sections.length;
  final sectionPlane = Theme.of(context).scaffoldBackgroundColor;

  final out = <Widget>[];
  for (var i = 0; i < sections.length; i++) {
    final section = sections[i];
    final showHeader = shouldShowShelfUniverseHeader(
      universeCount: universeCount,
      seriesInUniverse: section.series.length,
    );

    final sectionChildren = <Widget>[
      if (showHeader)
        Padding(
          padding: EdgeInsets.only(
            top: i == 0
                ? FeedRhythm.collectionUniverseSectionTop
                : FeedRhythm.collectionUniverseSectionGap,
            bottom: FeedRhythm.collectionUniverseHeaderToCards,
          ),
          child: CollectibleSectionHeader(
            title: section.label,
            padding: EdgeInsets.zero,
          ),
        )
      else if (i > 0)
        const SizedBox(height: FeedRhythm.collectionUniverseSectionGap),
      for (final s in section.series)
        SeriesShelfCard(
          series: s,
          progress: progressForSeries(s, figureStates),
          figureStates: figureStates,
          atmosphere: atmosphereForSeries(
            s,
            figureStates,
            shelfHarmony: shelfHarmony,
          ),
          onOpen: () => onOpen(s),
          onRemove: () => onRemove(s),
        ),
    ];

    out.add(
      ColoredBox(
        color: sectionPlane,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: sectionChildren,
        ),
      ),
    );
  }
  return out;
}
