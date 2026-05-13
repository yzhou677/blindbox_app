import 'package:blindbox_app/features/collection/data/collection_seed_data.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/home/data/mock_latest_drops.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// In-memory collection workflows. Persistence / APIs plug in here later.
final collectionNotifierProvider =
    NotifierProvider<CollectionNotifier, CollectionSnapshot>(CollectionNotifier.new);

class CollectionNotifier extends Notifier<CollectionSnapshot> {
  @override
  CollectionSnapshot build() => CollectionSeedData.initialSnapshot();

  void cycleFigure(String figureId) {
    if (!_figureExistsInCatalog(figureId)) return;
    final cur = state.trackedOrDefault(figureId);
    final TrackedFigure next;
    if (cur.owned) {
      next = TrackedFigure(figureId: figureId, owned: false, wishlist: false);
    } else if (cur.wishlist) {
      next = TrackedFigure(figureId: figureId, owned: true, wishlist: false);
    } else {
      next = TrackedFigure(figureId: figureId, owned: false, wishlist: true);
    }
    final m = Map<String, TrackedFigure>.from(state.figureStates);
    if (!next.owned && !next.wishlist) {
      m.remove(figureId);
    } else {
      m[figureId] = next;
    }
    state = CollectionSnapshot(
      officialIps: state.officialIps,
      customSeries: state.customSeries,
      figureStates: m,
    );
  }

  bool _figureExistsInCatalog(String figureId) {
    for (final s in state.allOfficialSeries) {
      for (final f in s.figures) {
        if (f.id == figureId) return true;
      }
    }
    for (final s in state.customSeries) {
      for (final f in s.figures) {
        if (f.id == figureId) return true;
      }
    }
    return false;
  }

  SeriesDefinition? _findSeries(String seriesId) {
    for (final s in state.allOfficialSeries) {
      if (s.id == seriesId) return s;
    }
    for (final s in state.customSeries) {
      if (s.id == seriesId) return s;
    }
    return null;
  }

  void addCustomSeries({
    required String seriesName,
    String? brand,
    String? ipDisplayName,
    required List<String> figureNames,
    String? notes,
  }) {
    final seriesId = 'custom-${DateTime.now().microsecondsSinceEpoch}';
    const accents = <Color>[
      Color(0xFFE8E4F8),
      Color(0xFFF2E8DC),
      Color(0xFFE4F2EA),
      Color(0xFFE4EDFA),
      Color(0xFFFCE4EC),
      Color(0xFFEAF6FB),
    ];
    final accent = accents[seriesId.hashCode.abs() % accents.length];
    final trimmedBrand = brand?.trim();
    final brandLine = (trimmedBrand == null || trimmedBrand.isEmpty) ? 'Independent' : trimmedBrand;
    final ipLine = (ipDisplayName?.trim().isEmpty ?? true)
        ? seriesName.trim()
        : ipDisplayName!.trim();
    final figures = <FigureDefinition>[];
    var i = 0;
    for (final raw in figureNames) {
      final name = raw.trim();
      if (name.isEmpty) continue;
      final fid = '$seriesId-f-$i';
      figures.add(
        FigureDefinition(
          id: fid,
          seriesId: seriesId,
          ipId: seriesId,
          name: name,
          imageUrl: mockCollectibleArtUrl('$seriesId-$i', 'f5f5f5'),
          rarity: 'Custom',
          isSecret: false,
        ),
      );
      i++;
    }
    if (figures.isEmpty) return;
    final trimmedNotes = notes?.trim();
    final series = SeriesDefinition(
      id: seriesId,
      name: seriesName.trim(),
      brand: brandLine,
      ipName: ipLine,
      figures: figures,
      shelfAccent: accent,
      notes: (trimmedNotes == null || trimmedNotes.isEmpty) ? null : trimmedNotes,
    );
    state = CollectionSnapshot(
      officialIps: state.officialIps,
      customSeries: [...state.customSeries, series],
      figureStates: state.figureStates,
    );
  }

  void removeCustomSeries(String seriesId) {
    final series = _findSeries(seriesId);
    if (series == null) return;
    final isCustom = state.customSeries.any((s) => s.id == seriesId);
    if (!isCustom) return;
    final m = Map<String, TrackedFigure>.from(state.figureStates);
    for (final f in series.figures) {
      m.remove(f.id);
    }
    state = CollectionSnapshot(
      officialIps: state.officialIps,
      customSeries: state.customSeries.where((s) => s.id != seriesId).toList(growable: false),
      figureStates: m,
    );
  }
}
