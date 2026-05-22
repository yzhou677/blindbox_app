import 'package:blindbox_app/features/collection/application/series_completion_atmosphere.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/collection/domain/shelf_emotional_profile.dart';
import 'package:blindbox_app/features/collection/widgets/series_shelf_cards.dart';
import 'package:blindbox_app/shared/widgets/collectible_section_header.dart';
import 'package:flutter/material.dart';

/// Builds shelf series cards with optional soft universe section labels.
List<Widget> buildShelfSeriesFeed({
  required List<ShelfSeries> series,
  required Map<String, TrackedFigure> figureStates,
  required void Function(ShelfSeries series) onOpen,
  required void Function(ShelfSeries series) onRemove,
  ShelfEmotionalProfile? profile,
}) {
  if (series.isEmpty) return const [];

  final shelfHarmony = profile?.themeIncludes(ShelfEditorialTheme.harmony) ?? false;
  final ipGroups = <String, List<ShelfSeries>>{};
  final ipOrder = <String>[];

  for (final s in series) {
    final key = s.taxonomyIpId?.trim().isNotEmpty == true
        ? s.taxonomyIpId!
        : s.ipName.trim();
    if (!ipGroups.containsKey(key)) {
      ipOrder.add(key);
      ipGroups[key] = [];
    }
    ipGroups[key]!.add(s);
  }

  final showIpHeaders = ipOrder.any((k) => (ipGroups[k]?.length ?? 0) >= 2);

  final out = <Widget>[];
  for (final ipKey in ipOrder) {
    final group = ipGroups[ipKey] ?? const [];
    if (showIpHeaders && group.length >= 2 && ipKey.isNotEmpty) {
      final label = group.first.ipName.trim().isNotEmpty
          ? shelfSeriesIpLabel(group.first)
          : ipKey;
      out.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 10, top: 4),
          child: CollectibleSectionHeader(
            title: label,
            padding: EdgeInsets.zero,
          ),
        ),
      );
    }
    for (final s in group) {
      final atmosphere = atmosphereForSeries(
        s,
        figureStates,
        shelfHarmony: shelfHarmony,
      );
      out.add(
        SeriesShelfCard(
          series: s,
          progress: progressForSeries(s, figureStates),
          figureStates: figureStates,
          atmosphere: atmosphere,
          onOpen: () => onOpen(s),
          onRemove: () => onRemove(s),
        ),
      );
    }
  }
  return out;
}
