import 'dart:convert';

import 'package:blindbox_app/features/collection/application/shelf_emotional_interpreter.dart';
import 'package:blindbox_app/features/collection/application/collection_evolution_interpreter.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/collection/domain/shelf_era.dart';
import 'package:blindbox_app/features/collection/domain/shelf_mood.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persisted collection journey milestones (offline, lightweight).
@immutable
class CollectionMemoryData {
  const CollectionMemoryData({
    this.firstSecretOwnedAtMs,
    this.lastCompletedSeriesId,
    this.lastCompletedAtMs,
    this.firstSeriesAddedAtMs,
    this.lastRecordedEra,
    this.priorEraForEvolution,
    this.priorEraSetAtMs,
    this.ipSeriesDepth = const {},
  });

  final int? firstSecretOwnedAtMs;
  final String? lastCompletedSeriesId;
  final int? lastCompletedAtMs;
  final int? firstSeriesAddedAtMs;
  final ShelfEra? lastRecordedEra;
  final ShelfEra? priorEraForEvolution;
  final int? priorEraSetAtMs;

  /// Taxonomy IP id → count of series added over time (depth, not social score).
  final Map<String, int> ipSeriesDepth;

  DateTime? get priorEraSetAt => priorEraSetAtMs == null
      ? null
      : DateTime.fromMillisecondsSinceEpoch(priorEraSetAtMs!);

  DateTime? get firstSecretOwnedAt => firstSecretOwnedAtMs == null
      ? null
      : DateTime.fromMillisecondsSinceEpoch(firstSecretOwnedAtMs!);

  DateTime? get lastCompletedAt => lastCompletedAtMs == null
      ? null
      : DateTime.fromMillisecondsSinceEpoch(lastCompletedAtMs!);

  DateTime? get firstSeriesAddedAt => firstSeriesAddedAtMs == null
      ? null
      : DateTime.fromMillisecondsSinceEpoch(firstSeriesAddedAtMs!);
}

/// Local prefs backing for shelf memory moments.
final class CollectionMemoryStore {
  CollectionMemoryStore._();

  static final CollectionMemoryStore instance = CollectionMemoryStore._();

  static const _prefsKeyV2 = 'collection_memory_v2';
  static const _prefsKeyV1 = 'collection_memory_v1';

  CollectionMemoryData _cached = const CollectionMemoryData();
  bool _loaded = false;

  CollectionMemoryData get cached {
    if (!_loaded) return const CollectionMemoryData();
    return _cached;
  }

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    final rawV2 = prefs.getString(_prefsKeyV2);
    if (rawV2 != null && rawV2.isNotEmpty) {
      _cached = _decode(rawV2);
    } else {
      final rawV1 = prefs.getString(_prefsKeyV1);
      if (rawV1 != null && rawV1.isNotEmpty) {
        _cached = _decodeV1(rawV1);
      }
    }
    _loaded = true;
  }

  Future<void> recordTransitions({
    required CollectionSnapshot previous,
    required CollectionSnapshot next,
  }) async {
    await ensureLoaded();
    var data = _cached;
    var changed = false;
    final now = DateTime.now().millisecondsSinceEpoch;

    if (data.firstSeriesAddedAtMs == null && previous.shelfSeries.isEmpty &&
        next.shelfSeries.isNotEmpty) {
      data = _copy(
        data,
        firstSeriesAddedAtMs: now,
      );
      changed = true;
    }

    final prevIds = previous.shelfSeries.map((s) => s.id).toSet();
    var depth = Map<String, int>.from(data.ipSeriesDepth);
    for (final series in next.shelfSeries) {
      if (prevIds.contains(series.id)) continue;
      final ip = series.taxonomyIpId?.trim();
      if (ip == null || ip.isEmpty) continue;
      depth[ip] = (depth[ip] ?? 0) + 1;
      changed = true;
    }
    if (depth != data.ipSeriesDepth) {
      data = _copy(data, ipSeriesDepth: depth);
    }

    if (data.firstSecretOwnedAtMs == null && _hasOwnedSecret(next)) {
      data = _copy(data, firstSecretOwnedAtMs: now);
      changed = true;
    }

    for (final series in next.shelfSeries) {
      if (!_wasSeriesComplete(previous, series.id) &&
          _isSeriesComplete(next, series.id)) {
        data = _copy(
          data,
          lastCompletedSeriesId: series.id,
          lastCompletedAtMs: now,
        );
        changed = true;
        break;
      }
    }

    final era = _eraFromSnapshot(next);
    if (era != null && !_erasEqual(era, data.lastRecordedEra)) {
      final prior = data.lastRecordedEra;
      data = _copy(
        data,
        lastRecordedEra: era,
        priorEraForEvolution: prior ?? data.priorEraForEvolution,
        priorEraSetAtMs: prior != null ? now : data.priorEraSetAtMs,
      );
      changed = true;
    }

    if (changed) {
      _cached = data;
      await _persist();
    }
  }

  static ShelfEra? _eraFromSnapshot(CollectionSnapshot snap) {
    if (snap.shelfSeries.isEmpty) return null;
    final profile = interpretShelf(snap);
    return shelfEraFromProfile(profile, snap.shelfSeries.length);
  }

  static bool _erasEqual(ShelfEra a, ShelfEra? b) {
    if (b == null) return false;
    return a.shelfMood == b.shelfMood &&
        a.dominantIpId == b.dominantIpId &&
        a.seriesCount == b.seriesCount &&
        a.secretOwnedCount == b.secretOwnedCount;
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    final era = _cached.lastRecordedEra;
    await prefs.setString(
      _prefsKeyV2,
      jsonEncode({
        'firstSecretOwnedAtMs': _cached.firstSecretOwnedAtMs,
        'lastCompletedSeriesId': _cached.lastCompletedSeriesId,
        'lastCompletedAtMs': _cached.lastCompletedAtMs,
        'firstSeriesAddedAtMs': _cached.firstSeriesAddedAtMs,
        'ipSeriesDepth': _cached.ipSeriesDepth,
        if (era != null) 'lastRecordedEra': _encodeEra(era),
        if (_cached.priorEraForEvolution != null)
          'priorEraForEvolution': _encodeEra(_cached.priorEraForEvolution!),
        'priorEraSetAtMs': _cached.priorEraSetAtMs,
      }),
    );
  }

  static Map<String, Object?> _encodeEra(ShelfEra era) => {
        'shelfMood': era.shelfMood.name,
        'seriesCount': era.seriesCount,
        'secretOwnedCount': era.secretOwnedCount,
        'dominantIpId': era.dominantIpId,
        'recordedAtMs': era.recordedAt?.millisecondsSinceEpoch,
      };

  static CollectionMemoryData _decode(String raw) {
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      return CollectionMemoryData(
        firstSecretOwnedAtMs: m['firstSecretOwnedAtMs'] as int?,
        lastCompletedSeriesId: m['lastCompletedSeriesId'] as String?,
        lastCompletedAtMs: m['lastCompletedAtMs'] as int?,
        firstSeriesAddedAtMs: m['firstSeriesAddedAtMs'] as int?,
        lastRecordedEra: _decodeEra(m['lastRecordedEra']),
        priorEraForEvolution: _decodeEra(m['priorEraForEvolution']),
        priorEraSetAtMs: m['priorEraSetAtMs'] as int?,
        ipSeriesDepth: _decodeDepth(m['ipSeriesDepth']),
      );
    } catch (_) {
      return const CollectionMemoryData();
    }
  }

  static CollectionMemoryData _decodeV1(String raw) {
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      return CollectionMemoryData(
        firstSecretOwnedAtMs: m['firstSecretOwnedAtMs'] as int?,
        lastCompletedSeriesId: m['lastCompletedSeriesId'] as String?,
        lastCompletedAtMs: m['lastCompletedAtMs'] as int?,
      );
    } catch (_) {
      return const CollectionMemoryData();
    }
  }

  static Map<String, int> _decodeDepth(Object? raw) {
    if (raw is! Map) return const {};
    return {
      for (final e in raw.entries)
        if (e.key is String && e.value is int) e.key as String: e.value as int,
    };
  }

  static ShelfEra? _decodeEra(Object? raw) {
    if (raw is! Map) return null;
    final moodName = raw['shelfMood'] as String?;
    final mood = ShelfMood.values.asNameMap()[moodName] ?? ShelfMood.growing;
    final atMs = raw['recordedAtMs'] as int?;
    return ShelfEra(
      shelfMood: mood,
      seriesCount: (raw['seriesCount'] as int?) ?? 0,
      secretOwnedCount: (raw['secretOwnedCount'] as int?) ?? 0,
      dominantIpId: raw['dominantIpId'] as String?,
      recordedAt:
          atMs == null ? null : DateTime.fromMillisecondsSinceEpoch(atMs),
    );
  }

  static CollectionMemoryData _copy(
    CollectionMemoryData data, {
    int? firstSecretOwnedAtMs,
    String? lastCompletedSeriesId,
    int? lastCompletedAtMs,
    int? firstSeriesAddedAtMs,
    ShelfEra? lastRecordedEra,
    ShelfEra? priorEraForEvolution,
    int? priorEraSetAtMs,
    Map<String, int>? ipSeriesDepth,
  }) {
    return CollectionMemoryData(
      firstSecretOwnedAtMs:
          firstSecretOwnedAtMs ?? data.firstSecretOwnedAtMs,
      lastCompletedSeriesId:
          lastCompletedSeriesId ?? data.lastCompletedSeriesId,
      lastCompletedAtMs: lastCompletedAtMs ?? data.lastCompletedAtMs,
      firstSeriesAddedAtMs: firstSeriesAddedAtMs ?? data.firstSeriesAddedAtMs,
      lastRecordedEra: lastRecordedEra ?? data.lastRecordedEra,
      priorEraForEvolution:
          priorEraForEvolution ?? data.priorEraForEvolution,
      priorEraSetAtMs: priorEraSetAtMs ?? data.priorEraSetAtMs,
      ipSeriesDepth: ipSeriesDepth ?? data.ipSeriesDepth,
    );
  }

  static bool _hasOwnedSecret(CollectionSnapshot snap) {
    for (final series in snap.shelfSeries) {
      for (final fig in series.figures) {
        if (fig.isSecret && snap.trackedOrDefault(fig.id).owned) {
          return true;
        }
      }
    }
    return false;
  }

  static bool _isSeriesComplete(CollectionSnapshot snap, String seriesId) {
    for (final series in snap.shelfSeries) {
      if (series.id != seriesId) continue;
      final p = progressForSeries(series, snap.figureStates);
      return series.figureCount > 0 && p.owned >= series.figureCount;
    }
    return false;
  }

  static bool _wasSeriesComplete(CollectionSnapshot snap, String seriesId) {
    return _isSeriesComplete(snap, seriesId);
  }

  void resetForTest() {
    _cached = const CollectionMemoryData();
    _loaded = true;
  }
}
