import 'dart:async';

import 'package:blindbox_app/features/collection/bootstrap/collection_app_bootstrap.dart';
import 'package:blindbox_app/features/collection/data/collection_input_sanitizer.dart';
import 'package:blindbox_app/features/collection/data/collection_taxonomy_canonicalizer.dart';
import 'package:blindbox_app/features/collection/data/custom_series_conventions.dart';
import 'package:blindbox_app/features/collection/data/series_release_lookup.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/collection/data/collection_memory_store.dart';
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
  // Debounce window for persistence writes.  Rapid figure-state cycling (e.g.
  // tapping slots quickly) produces many successive commits; coalescing them
  // into one disk write reduces snapshot-encode + SharedPreferences churn
  // without any perceived lag (UI state updates are still instant).
  static const _persistenceDebounce = Duration(milliseconds: 350);

  Timer? _persistenceTimer;

  // The snapshot state *before* the current pending debounce window began.
  // Passed to recordTransitions as the "true previous" so that the net change
  // across the entire rapid-tap sequence is correctly detected.
  CollectionSnapshot? _pendingPersistencePrevious;

  @override
  CollectionSnapshot build() {
    ref.onDispose(_flushPendingPersistence);
    return CollectionAppBootstrap.takeInitialSnapshot();
  }

  void _commit(CollectionSnapshot next) {
    // UI state update is instant — providers and widgets rebuild immediately.
    final previous = state;
    state = next;

    // Capture the snapshot that preceded this debounce window on first tap.
    _pendingPersistencePrevious ??= previous;

    // Cancel any scheduled persistence flush and reschedule.
    _persistenceTimer?.cancel();
    _persistenceTimer = Timer(
      _persistenceDebounce,
      () => unawaited(_persistPendingSnapshot()),
    );
  }

  /// Persists the coalesced debounce window — snapshot + journey memory.
  ///
  /// Clears [_pendingPersistencePrevious] before awaiting I/O so a concurrent
  /// timer tick or [ref.onDispose] flush cannot record the same transition twice.
  Future<void> _persistPendingSnapshot() async {
    final truePrevious = _pendingPersistencePrevious;
    if (truePrevious == null) return;

    _persistenceTimer?.cancel();
    _persistenceTimer = null;
    _pendingPersistencePrevious = null;

    final current = state;

    // TODO(perf/scale): move CollectionSnapshotCodec.encode (jsonEncode of
    // entire shelf) and CollectionMemoryStore.recordTransitions
    // (interpretShelf) to Isolate.run once shelf sizes commonly exceed
    // ~100 series / ~1000 figures. At indie scale the encode completes in
    // <50 ms and does not require isolate offloading.
    await CollectionSnapshotStorage.save(current);
    await CollectionMemoryStore.instance.recordTransitions(
      previous: truePrevious,
      next: current,
    );
  }

  /// Cancels any pending debounce timer and immediately flushes to disk.
  ///
  /// Called from [ref.onDispose] so no writes are lost when the notifier is
  /// torn down (e.g. app termination or hot-restart in dev).
  void _flushPendingPersistence() {
    unawaited(_persistPendingSnapshot());
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
      addSeriesFromRelease(fromRelease);
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
      imageUrl: null,
      localImageUri: null,
      rarity: 'Regular',
      isSecret: false,
      imageKey: c.id,
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

  /// Adds a Home **series release** (full lineup) under `drop-{dropId}` — optimistic commit.
  ///
  /// Shelf UI renders from [ShelfFigure.imageKey] via [CatalogImageFromKey]; no URL hydration.
  void addSeriesFromRelease(SeriesRelease release) {
    final catalogKey = 'drop-${release.dropId}';
    if (state.hasTemplateOnShelf(catalogKey)) return;
    final seriesId =
        'shelf-$catalogKey-${DateTime.now().microsecondsSinceEpoch}';
    final hero = release.heroCollectible;
    final figures = <ShelfFigure>[];
    for (final slot in release.lineup) {
      final figureKey = slot.imageKey.trim();
      figures.add(
        ShelfFigure(
          id: '$seriesId-slot-${slot.slotId}',
          seriesId: seriesId,
          name: slot.name,
          imageUrl: null,
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
    final meta = _sanitizeCustomSeriesMetadata(
      seriesName: seriesName,
      brand: brand,
      ipDisplayName: ipDisplayName,
      notes: notes,
    );
    final displayName = meta.displayName;
    if (displayName.isEmpty) return;
    final taxonomy = _resolveCustomSeriesTaxonomy(
      displayName: displayName,
      trimmedBrand: meta.brand,
      ipDisplayName: meta.ipDisplayName,
    );
    final brandLine = taxonomy.brandLine;
    final brandId = taxonomy.brandId;
    final ipId = taxonomy.ipId;
    final resolvedIpName = taxonomy.ipName;
    final shelfFigures = <ShelfFigure>[];
    var i = 0;
    for (final draft in figures) {
      final figName = CollectionInputSanitizer.figureName(draft.displayName);
      if (figName == null || figName.isEmpty) continue;
      final figId = CustomSeriesConventions.figureImageKey(seriesId, i);
      final imageKey = CustomSeriesConventions.figureImageKey(seriesId, i);
      final local = draft.localImageUri?.trim();
      final rarityLabel = draft.isSecret
          ? CollectionInputSanitizer.rarityLabel(draft.rarityLabel)
          : null;
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
    final trimmedCover = customCoverImageUri?.trim();
    final series = ShelfSeries(
      id: seriesId,
      name: displayName,
      brand: brandLine,
      ipName: resolvedIpName,
      figures: shelfFigures,
      shelfAccent: accent,
      notes: meta.notes,
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

  void updateCustomSeries({
    required String seriesId,
    required String seriesName,
    String? brand,
    String? ipDisplayName,
    String? customCoverImageUri,
    String? notes,
  }) {
    final existing = _findSeries(seriesId);
    if (existing == null || !existing.isCustomLocal) return;

    final meta = _sanitizeCustomSeriesMetadata(
      seriesName: seriesName,
      brand: brand,
      ipDisplayName: ipDisplayName,
      notes: notes,
    );
    final displayName = meta.displayName;
    if (displayName.isEmpty) return;

    final taxonomy = _resolveCustomSeriesTaxonomy(
      displayName: displayName,
      trimmedBrand: meta.brand,
      ipDisplayName: meta.ipDisplayName,
    );

    final trimmedCover = customCoverImageUri?.trim();

    final updatedFigures = [
      for (final f in existing.figures)
        ShelfFigure(
          id: f.id,
          seriesId: f.seriesId,
          name: f.name,
          imageUrl: f.imageUrl,
          localImageUri: f.localImageUri,
          imageKey: f.imageKey,
          rarity: f.rarity,
          isSecret: f.isSecret,
          rarityLabel: f.rarityLabel,
          catalogFigureTemplateId: f.catalogFigureTemplateId,
          taxonomyBrandId: taxonomy.brandId,
          taxonomyIpId: taxonomy.ipId,
        ),
    ];

    final updated = ShelfSeries(
      id: existing.id,
      name: displayName,
      brand: taxonomy.brandLine,
      ipName: taxonomy.ipName,
      figures: updatedFigures,
      shelfAccent: existing.shelfAccent,
      notes: meta.notes,
      catalogTemplateId: null,
      taxonomyBrandId: taxonomy.brandId,
      taxonomyIpId: taxonomy.ipId,
      imageKey: existing.imageKey,
      customCoverImageUri: (trimmedCover != null && trimmedCover.isNotEmpty)
          ? trimmedCover
          : null,
    );

    _commit(
      CollectionSnapshot(
        shelfSeries: [
          for (final s in state.shelfSeries)
            if (s.id == seriesId) updated else s,
        ],
        figureStates: state.figureStates,
      ),
    );
  }

  void updateCustomFigure({
    required String seriesId,
    required String figureId,
    required String name,
    required bool isSecret,
    String? rarityLabel,
    String? localImageUri,
  }) {
    final existing = _findSeries(seriesId);
    if (existing == null || !existing.isCustomLocal) return;

    final index = existing.figures.indexWhere((f) => f.id == figureId);
    if (index < 0) return;

    final figName = CollectionInputSanitizer.figureName(name);
    if (figName == null || figName.isEmpty) return;

    final old = existing.figures[index];
    final sanitizedRarity = isSecret
        ? CollectionInputSanitizer.rarityLabel(rarityLabel)
        : null;
    final trimmedUri = localImageUri?.trim();
    final resolvedUri =
        (trimmedUri != null && trimmedUri.isNotEmpty) ? trimmedUri : null;

    final updatedFigure = ShelfFigure(
      id: old.id,
      seriesId: old.seriesId,
      name: figName,
      imageUrl: old.imageUrl,
      localImageUri: resolvedUri,
      imageKey: old.imageKey,
      rarity: CustomSeriesConventions.rarityLine(
        isSecret: isSecret,
        rarityLabel: sanitizedRarity,
      ),
      isSecret: isSecret,
      rarityLabel: (sanitizedRarity != null && sanitizedRarity.isNotEmpty)
          ? sanitizedRarity
          : null,
      catalogFigureTemplateId: old.catalogFigureTemplateId,
      taxonomyBrandId: old.taxonomyBrandId,
      taxonomyIpId: old.taxonomyIpId,
    );

    final updatedFigures = List<ShelfFigure>.from(existing.figures);
    updatedFigures[index] = updatedFigure;

    final updatedSeries = ShelfSeries(
      id: existing.id,
      name: existing.name,
      brand: existing.brand,
      ipName: existing.ipName,
      figures: updatedFigures,
      shelfAccent: existing.shelfAccent,
      notes: existing.notes,
      catalogTemplateId: existing.catalogTemplateId,
      taxonomyBrandId: existing.taxonomyBrandId,
      taxonomyIpId: existing.taxonomyIpId,
      imageKey: existing.imageKey,
      customCoverImageUri: existing.customCoverImageUri,
    );

    _commit(
      CollectionSnapshot(
        shelfSeries: [
          for (final s in state.shelfSeries)
            if (s.id == seriesId) updatedSeries else s,
        ],
        figureStates: state.figureStates,
      ),
    );
  }

  ({
    String displayName,
    String? brand,
    String? ipDisplayName,
    String? notes,
  }) _sanitizeCustomSeriesMetadata({
    required String seriesName,
    String? brand,
    String? ipDisplayName,
    String? notes,
  }) {
    return (
      displayName: CollectionInputSanitizer.seriesName(seriesName),
      brand: CollectionInputSanitizer.brand(brand),
      ipDisplayName: CollectionInputSanitizer.ip(ipDisplayName),
      notes: CollectionInputSanitizer.notes(notes),
    );
  }

  ({String brandLine, String brandId, String ipName, String ipId})
  _resolveCustomSeriesTaxonomy({
    required String displayName,
    String? trimmedBrand,
    String? ipDisplayName,
  }) {
    final brandCanon = CollectionTaxonomyCanonicalizer.resolveBrandFromUserInput(
      trimmedBrand,
    );
    final ipLine = (ipDisplayName?.trim().isEmpty ?? true)
        ? displayName
        : ipDisplayName!.trim();
    final ipCanon = CollectionTaxonomyCanonicalizer.resolveIpFromUserInput(
      ipLine,
    );
    return (
      brandLine: brandCanon.displayLabel,
      brandId: brandCanon.taxonomyId,
      ipName: ipCanon.displayLabel,
      ipId: ipCanon.taxonomyId,
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
