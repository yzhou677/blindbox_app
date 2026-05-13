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
    if (!_figureOnShelf(figureId)) return;
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
      shelfSeries: state.shelfSeries,
      figureStates: m,
    );
  }

  bool _figureOnShelf(String figureId) {
    for (final s in state.shelfSeries) {
      for (final f in s.figures) {
        if (f.id == figureId) return true;
      }
    }
    return false;
  }

  SeriesDefinition? _findSeries(String seriesId) {
    for (final s in state.shelfSeries) {
      if (s.id == seriesId) return s;
    }
    return null;
  }

  /// Adds a cloned row from a catalog template (suggestions / browse). No-op if that template is already on shelf.
  void addSeriesFromTemplate(SeriesDefinition template) {
    final catalogKey = template.catalogTemplateId ?? template.id;
    if (state.hasTemplateOnShelf(catalogKey)) return;
    final newSeriesId = 'shelf-$catalogKey-${DateTime.now().microsecondsSinceEpoch}';
    final cloned = cloneSeriesOntoShelf(
      template,
      newSeriesId,
      catalogTemplateKey: catalogKey,
    );
    state = CollectionSnapshot(
      shelfSeries: [...state.shelfSeries, cloned],
      figureStates: state.figureStates,
    );
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
      catalogTemplateId: null,
    );
    state = CollectionSnapshot(
      shelfSeries: [...state.shelfSeries, series],
      figureStates: state.figureStates,
    );
  }

  void removeSeries(String seriesId) {
    final series = _findSeries(seriesId);
    if (series == null) return;
    final m = Map<String, TrackedFigure>.from(state.figureStates);
    for (final f in series.figures) {
      m.remove(f.id);
    }
    state = CollectionSnapshot(
      shelfSeries: state.shelfSeries.where((s) => s.id != seriesId).toList(growable: false),
      figureStates: m,
    );
  }
}
