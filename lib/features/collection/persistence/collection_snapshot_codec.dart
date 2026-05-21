import 'dart:convert';

import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:flutter/material.dart';

const _schemaVersion = 2;

/// JSON payload for [CollectionSnapshot] — catalog-aligned keys on wire where practical.
abstract final class CollectionSnapshotCodec {
  static String encode(CollectionSnapshot snap) {
    return jsonEncode({
      'v': _schemaVersion,
      'shelfSeries': [for (final s in snap.shelfSeries) _seriesToJson(s)],
      'figureStates': {
        for (final e in snap.figureStates.entries) e.key: e.value.state.name,
      },
    });
  }

  static CollectionSnapshot? tryDecode(String raw) {
    try {
      final dynamic data = jsonDecode(raw);
      if (data is! Map) return null;
      final map = Map<String, dynamic>.from(data);
      final v = map['v'];
      if (v is! int || v < 1 || v > _schemaVersion) return null;
      final seriesRaw = map['shelfSeries'];
      if (seriesRaw is! List) return null;
      final shelfSeries = <ShelfSeries>[];
      for (final item in seriesRaw) {
        final s = _seriesFromJson(item);
        if (s == null) return null;
        shelfSeries.add(s);
      }
      final statesRaw = map['figureStates'];
      if (statesRaw is! Map) return null;
      final sm = Map<String, dynamic>.from(statesRaw);
      final figureStates = <String, TrackedFigure>{};
      for (final e in sm.entries) {
        final id = e.key;
        if (id.isEmpty) continue;
        final tf = _trackedFromJson(id, e.value);
        if (tf == null) continue;
        if (tf.state == FigureCollectionState.none) continue;
        figureStates[id] = tf;
      }
      return CollectionSnapshot(shelfSeries: shelfSeries, figureStates: figureStates);
    } catch (_) {
      return null;
    }
  }

  static Map<String, dynamic> _seriesToJson(ShelfSeries s) {
    final brandId = s.taxonomyBrandId;
    final ipId = s.taxonomyIpId;
    return {
      'id': s.id,
      'displayName': s.name,
      'name': s.name,
      'brand': s.brand,
      'ipName': s.ipName,
      'brandId': ?brandId,
      'ipId': ?ipId,
      'imageKey': ?s.imageKey,
      'notes': s.notes,
      'catalogTemplateId': s.catalogTemplateId,
      'taxonomyBrandId': brandId,
      'taxonomyIpId': ipId,
      'customCoverImageUri': s.customCoverImageUri,
      'shelfAccentArgb': _colorToArgb(s.shelfAccent),
      'figures': [for (final f in s.figures) _figureToJson(f)],
    };
  }

  static ShelfSeries? _seriesFromJson(dynamic raw) {
    if (raw is! Map) return null;
    final m = Map<String, dynamic>.from(raw);
    final id = m['id'] as String?;
    final displayName = (m['displayName'] as String?) ?? (m['name'] as String?);
    final brand = m['brand'] as String?;
    final ipName = m['ipName'] as String?;
    if (id == null || displayName == null || brand == null || ipName == null) return null;
    final accent = _colorFromArgb(m['shelfAccentArgb']);
    if (accent == null) return null;
    final figsRaw = m['figures'];
    if (figsRaw is! List) return null;
    final figures = <ShelfFigure>[];
    for (final fr in figsRaw) {
      final f = _figureFromJson(fr);
      if (f == null) return null;
      figures.add(f);
    }
    final brandId = (m['brandId'] as String?) ?? (m['taxonomyBrandId'] as String?);
    final ipId = (m['ipId'] as String?) ?? (m['taxonomyIpId'] as String?);
    final imageKey = (m['imageKey'] as String?) ?? (m['catalogTemplateId'] as String?);
    return ShelfSeries(
      id: id,
      name: displayName,
      brand: brand,
      ipName: ipName,
      figures: figures,
      shelfAccent: accent,
      notes: m['notes'] as String?,
      catalogTemplateId: m['catalogTemplateId'] as String?,
      taxonomyBrandId: brandId,
      taxonomyIpId: ipId,
      imageKey: imageKey,
      customCoverImageUri: m['customCoverImageUri'] as String?,
    );
  }

  static Map<String, dynamic> _figureToJson(ShelfFigure f) {
    return {
      'id': f.id,
      'seriesId': f.seriesId,
      'displayName': f.name,
      'name': f.name,
      'imageKey': ?f.imageKey,
      'imageUrl': f.imageUrl,
      'localImageUri': f.localImageUri,
      'rarity': f.rarity,
      'rarityLabel': ?f.rarityLabel,
      'isSecret': f.isSecret,
      'taxonomyBrandId': f.taxonomyBrandId,
      'taxonomyIpId': f.taxonomyIpId,
      'catalogFigureTemplateId': f.catalogFigureTemplateId,
    };
  }

  static ShelfFigure? _figureFromJson(dynamic raw) {
    if (raw is! Map) return null;
    final m = Map<String, dynamic>.from(raw);
    final id = m['id'] as String?;
    final seriesId = m['seriesId'] as String?;
    final displayName = (m['displayName'] as String?) ?? (m['name'] as String?);
    final isSecret = m['isSecret'] as bool? ?? false;
    if (id == null || seriesId == null || displayName == null) return null;

    final rarityLabel = m['rarityLabel'] as String?;
    final legacyRarity = m['rarity'] as String?;
    final migratedLabel = _migrateRarityLabel(rarityLabel, legacyRarity, isSecret);
    final rarity = legacyRarity ?? _rarityLine(isSecret, migratedLabel);

    return ShelfFigure(
      id: id,
      seriesId: seriesId,
      name: displayName,
      imageUrl: m['imageUrl'] as String?,
      localImageUri: m['localImageUri'] as String?,
      imageKey: (m['imageKey'] as String?) ?? id,
      rarity: rarity,
      isSecret: isSecret,
      rarityLabel: migratedLabel,
      taxonomyBrandId: m['taxonomyBrandId'] as String?,
      taxonomyIpId: m['taxonomyIpId'] as String?,
      catalogFigureTemplateId: m['catalogFigureTemplateId'] as String?,
    );
  }

  static String? _migrateRarityLabel(String? rarityLabel, String? legacyRarity, bool isSecret) {
    final label = rarityLabel?.trim();
    if (label != null && label.isNotEmpty) return label;
    final legacy = legacyRarity?.trim();
    if (legacy != null && RegExp(r'^\d+\s*:\s*\d+\s*$').hasMatch(legacy)) return legacy;
    return null;
  }

  static String _rarityLine(bool isSecret, String? rarityLabel) {
    final label = rarityLabel?.trim();
    if (label != null && label.isNotEmpty) return label;
    return isSecret ? 'Secret' : 'Regular';
  }

  /// Supports enum name string (v1) or legacy `{ "owned": bool, "wishlist": bool }`.
  static TrackedFigure? _trackedFromJson(String figureId, dynamic raw) {
    if (raw is String) {
      try {
        final st = FigureCollectionState.values.byName(raw);
        return TrackedFigure(figureId: figureId, state: st);
      } catch (_) {
        return null;
      }
    }
    if (raw is Map) {
      final o = raw['owned'] == true;
      final w = raw['wishlist'] == true;
      if (o && w) {
        return TrackedFigure(figureId: figureId, state: FigureCollectionState.owned);
      }
      if (o) return TrackedFigure(figureId: figureId, state: FigureCollectionState.owned);
      if (w) return TrackedFigure(figureId: figureId, state: FigureCollectionState.wishlist);
      return TrackedFigure(figureId: figureId, state: FigureCollectionState.none);
    }
    return null;
  }

  static int _colorToArgb(Color c) {
    return ((c.a * 255.0).round() & 0xff) << 24 |
        ((c.r * 255.0).round() & 0xff) << 16 |
        ((c.g * 255.0).round() & 0xff) << 8 |
        ((c.b * 255.0).round() & 0xff);
  }

  static Color? _colorFromArgb(dynamic v) {
    if (v is! int) return null;
    return Color(v);
  }
}
