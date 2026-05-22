import 'dart:async';

import 'package:blindbox_app/features/catalog/catalog_image_resolver.dart';
import 'package:blindbox_app/features/collection/bootstrap/collection_app_bootstrap.dart';
import 'package:blindbox_app/features/collection/data/custom_series_conventions.dart';
import 'package:blindbox_app/features/collection/data/series_release_lookup.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/collection/persistence/collection_snapshot_storage.dart';
import 'package:blindbox_app/features/home/domain/series_release.dart';
import 'package:blindbox_app/models/collectible.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// In-memory collection workflows with durable local persistence.
final collectionNotifierProvider =
    NotifierProvider<CollectionNotifier, CollectionSnapshot>(
      CollectionNotifier.new,
    );

class CollectionNotifier extends Notifier<CollectionSnapshot> {
  @override
  CollectionSnapshot build() => CollectionAppBootstrap.takeInitialSnapshot();

  void _commit(CollectionSnapshot next) {
    state = next;
    unawaited(CollectionSnapshotStorage.save(next));
  }

  void cycleFigure(String figureId) {
    if (!_figureOnShelf(figureId)) return;
    final cur = state.trackedOrDefault(figureId);
    final FigureCollectionState nextState;
    switch (cur.state) {
      case FigureCollectionState.owned:
        nextState = FigureCollectionState.none;
      case FigureCollectionState.wishlist:
        nextState = FigureCollectionState.owned;
      case FigureCollectionState.none:
        nextState = FigureCollectionState.wishlist;
    }
    final m = Map<String, TrackedFigure>.from(state.figureStates);
    if (nextState == FigureCollectionState.none) {
      m.remove(figureId);
    } else {
      m[figureId] = TrackedFigure(figureId: figureId, state: nextState);
    }
    _commit(
      CollectionSnapshot(shelfSeries: state.shelfSeries, figureStates: m),
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

  ShelfSeries? _findSeries(String seriesId) {
    for (final s in state.shelfSeries) {
      if (s.id == seriesId) return s;
    }
    return null;
  }

  /// Adds a cloned row from a catalog template (suggestions / browse). No-op if that template is already on shelf.
  ///
  /// When [c.id] matches a Home [SeriesRelease], adds the **full lineup** as one shelf series.
  void addSeriesFromDrop(Collectible c) {
    final fromRelease = ref.read(seriesReleaseLookupProvider)(c.id);
    if (fromRelease != null) {
      unawaited(addSeriesFromRelease(fromRelease));
      return;
    }
    final catalogKey = 'drop-${c.id}';
    if (state.hasTemplateOnShelf(catalogKey)) return;
    final seriesId =
        'shelf-$catalogKey-${DateTime.now().microsecondsSinceEpoch}';
    final fid = '$seriesId-fig-0';
    final figure = ShelfFigure(
      id: fid,
      seriesId: seriesId,
      name: c.name,
      imageUrl: c.imageUrl,
      localImageUri: null,
      rarity: 'Regular',
      isSecret: false,
    );
    final series = ShelfSeries(
      id: seriesId,
      name: c.series,
      brand: c.brand,
      ipName: shelfIpLabelFromBrandLine(
        brand: c.brand,
        line: (c.ipLine?.trim().isNotEmpty ?? false) ? c.ipLine!.trim() : c.series,
      ),
      figures: [figure],
      shelfAccent: c.shelfAccent ?? const Color(0xFFE8DEF5),
      notes: null,
      catalogTemplateId: catalogKey,
      imageKey: catalogKey,
    );
    _commit(
      CollectionSnapshot(
        shelfSeries: [series, ...state.shelfSeries],
        figureStates: state.figureStates,
      ),
    );
  }

  /// Adds a Home **series release** (full lineup) to the shelf under `drop-{dropId}`.
  Future<void> addSeriesFromRelease(SeriesRelease release) async {
    final catalogKey = 'drop-${release.dropId}';
    if (state.hasTemplateOnShelf(catalogKey)) return;
    final seriesId =
        'shelf-$catalogKey-${DateTime.now().microsecondsSinceEpoch}';
    final hero = release.heroCollectible;
    final figures = <ShelfFigure>[];
    for (final slot in release.lineup) {
      final figureKey = slot.imageKey.trim();
      final imageUrl = figureKey.isNotEmpty
          ? await CatalogImageResolver.resolveFigureDisplayRef(figureKey)
          : slot.imageUrl?.trim();
      figures.add(
        ShelfFigure(
          id: '$seriesId-slot-${slot.slotId}',
          seriesId: seriesId,
          name: slot.name,
          imageUrl: imageUrl != null && imageUrl.isNotEmpty ? imageUrl : null,
          localImageUri: null,
          rarity: slot.isSecret ? 'Secret' : 'Regular',
          isSecret: slot.isSecret,
          imageKey: figureKey.isNotEmpty ? figureKey : null,
          taxonomyBrandId: release.taxonomyBrandId,
          taxonomyIpId: release.taxonomyIpId,
          catalogFigureTemplateId: slot.slotId,
        ),
      );
    }
    final series = ShelfSeries(
      id: seriesId,
      name: release.seriesName,
      brand: release.brand,
      ipName: shelfIpLabelFromBrandLine(
        brand: release.brand,
        line: (release.ipLine?.trim().isNotEmpty ?? false)
            ? release.ipLine!.trim()
            : release.seriesName,
      ),
      figures: figures,
      shelfAccent: hero.shelfAccent ?? const Color(0xFFE8DEF5),
      notes: null,
      catalogTemplateId: catalogKey,
      imageKey: release.seriesImageKey,
      taxonomyBrandId: release.taxonomyBrandId,
      taxonomyIpId: release.taxonomyIpId,
    );
    _commit(
      CollectionSnapshot(
        shelfSeries: [series, ...state.shelfSeries],
        figureStates: state.figureStates,
      ),
    );
  }

  void addSeriesFromTemplate(CatalogSeries template) {
    final catalogKey = template.templateId;
    if (state.hasTemplateOnShelf(catalogKey)) return;
    final newSeriesId =
        'shelf-$catalogKey-${DateTime.now().microsecondsSinceEpoch}';
    final cloned = cloneCatalogSeriesOntoShelf(
      template,
      newSeriesId,
      catalogTemplateKey: catalogKey,
    );
    _commit(
      CollectionSnapshot(
        shelfSeries: [cloned, ...state.shelfSeries],
        figureStates: state.figureStates,
      ),
    );
  }

  void addCustomSeries({
    required String seriesName,
    String? brand,
    String? ipDisplayName,
    required List<CustomFigureDraft> figures,
    String? customCoverImageUri,
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
    final displayName = seriesName.trim();
    final trimmedBrand = brand?.trim();
    final brandLine = (trimmedBrand == null || trimmedBrand.isEmpty)
        ? 'Independent'
        : trimmedBrand;
    final ipLine = (ipDisplayName?.trim().isEmpty ?? true)
        ? displayName
        : ipDisplayName!.trim();
    final brandId = CustomSeriesConventions.brandIdFromDisplay(trimmedBrand);
    final ipId = CustomSeriesConventions.ipIdFromDisplay(
      seriesDisplayName: displayName,
      ipDisplayName: ipDisplayName,
    );
    final shelfFigures = <ShelfFigure>[];
    var i = 0;
    for (final draft in figures) {
      final figName = draft.displayName.trim();
      if (figName.isEmpty) continue;
      final figId = CustomSeriesConventions.figureImageKey(seriesId, i);
      final imageKey = CustomSeriesConventions.figureImageKey(seriesId, i);
      final local = draft.localImageUri?.trim();
      final rarityLabel = draft.isSecret ? draft.rarityLabel?.trim() : null;
      shelfFigures.add(
        ShelfFigure(
          id: figId,
          seriesId: seriesId,
          name: figName,
          imageUrl: null,
          localImageUri: (local != null && local.isNotEmpty) ? local : null,
          imageKey: imageKey,
          rarity: CustomSeriesConventions.rarityLine(
            isSecret: draft.isSecret,
            rarityLabel: rarityLabel,
          ),
          isSecret: draft.isSecret,
          rarityLabel: (rarityLabel != null && rarityLabel.isNotEmpty)
              ? rarityLabel
              : null,
          taxonomyBrandId: brandId,
          taxonomyIpId: ipId,
        ),
      );
      i++;
    }
    if (shelfFigures.isEmpty) return;
    final trimmedNotes = notes?.trim();
    final trimmedCover = customCoverImageUri?.trim();
    final series = ShelfSeries(
      id: seriesId,
      name: displayName,
      brand: brandLine,
      ipName: ipLine,
      figures: shelfFigures,
      shelfAccent: accent,
      notes: (trimmedNotes == null || trimmedNotes.isEmpty)
          ? null
          : trimmedNotes,
      catalogTemplateId: null,
      taxonomyBrandId: brandId,
      taxonomyIpId: ipId,
      imageKey: CustomSeriesConventions.seriesImageKey(seriesId),
      customCoverImageUri: (trimmedCover != null && trimmedCover.isNotEmpty)
          ? trimmedCover
          : null,
    );
    _commit(
      CollectionSnapshot(
        shelfSeries: [series, ...state.shelfSeries],
        figureStates: state.figureStates,
      ),
    );
  }

  void removeSeries(String seriesId) {
    final series = _findSeries(seriesId);
    if (series == null) return;
    final m = Map<String, TrackedFigure>.from(state.figureStates);
    for (final f in series.figures) {
      m.remove(f.id);
    }
    _commit(
      CollectionSnapshot(
        shelfSeries: state.shelfSeries
            .where((s) => s.id != seriesId)
            .toList(growable: false),
        figureStates: m,
      ),
    );
  }

  /// Removes the shelf row for a catalog or drop template key (e.g. `drop-{id}`).
  void removeSeriesByCatalogTemplate(String catalogTemplateId) {
    for (final s in state.shelfSeries) {
      if (s.catalogTemplateId == catalogTemplateId) {
        removeSeries(s.id);
        return;
      }
    }
  }
}
