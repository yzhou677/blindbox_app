import 'dart:convert';

import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:flutter/material.dart';

const _schemaVersion = 2;

/// JSON payload for [CollectionSnapshot] — no [Color] in wire shape (ARGB int only).
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
    return {
      'id': s.id,
      'name': s.name,
      'brand': s.brand,
      'ipName': s.ipName,
      'notes': s.notes,
      'catalogTemplateId': s.catalogTemplateId,
      'taxonomyBrandId': s.taxonomyBrandId,
      'taxonomyIpId': s.taxonomyIpId,
      'customCoverImageUri': s.customCoverImageUri,
      'shelfAccentArgb': _colorToArgb(s.shelfAccent),
      'figures': [for (final f in s.figures) _figureToJson(f)],
    };
  }

  static ShelfSeries? _seriesFromJson(dynamic raw) {
    if (raw is! Map) return null;
    final m = Map<String, dynamic>.from(raw);
    final id = m['id'] as String?;
    final name = m['name'] as String?;
    final brand = m['brand'] as String?;
    final ipName = m['ipName'] as String?;
    if (id == null || name == null || brand == null || ipName == null) return null;
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
    return ShelfSeries(
      id: id,
      name: name,
      brand: brand,
      ipName: ipName,
      figures: figures,
      shelfAccent: accent,
      notes: m['notes'] as String?,
      catalogTemplateId: m['catalogTemplateId'] as String?,
      taxonomyBrandId: m['taxonomyBrandId'] as String?,
      taxonomyIpId: m['taxonomyIpId'] as String?,
      customCoverImageUri: m['customCoverImageUri'] as String?,
    );
  }

  static Map<String, dynamic> _figureToJson(ShelfFigure f) {
    return {
      'id': f.id,
      'seriesId': f.seriesId,
      'name': f.name,
      'imageUrl': f.imageUrl,
      'localImageUri': f.localImageUri,
      'rarity': f.rarity,
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
    final name = m['name'] as String?;
    final rarity = m['rarity'] as String?;
    final isSecret = m['isSecret'] as bool? ?? false;
    if (id == null || seriesId == null || name == null || rarity == null) return null;
    return ShelfFigure(
      id: id,
      seriesId: seriesId,
      name: name,
      imageUrl: m['imageUrl'] as String?,
      localImageUri: m['localImageUri'] as String?,
      rarity: rarity,
      isSecret: isSecret,
      taxonomyBrandId: m['taxonomyBrandId'] as String?,
      taxonomyIpId: m['taxonomyIpId'] as String?,
      catalogFigureTemplateId: m['catalogFigureTemplateId'] as String?,
    );
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
