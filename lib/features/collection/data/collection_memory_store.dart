import 'dart:convert';

import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persisted collection journey milestones (foundation only).
@immutable
class CollectionMemoryData {
  const CollectionMemoryData({
    this.firstSecretOwnedAtMs,
    this.lastCompletedSeriesId,
    this.lastCompletedAtMs,
  });

  final int? firstSecretOwnedAtMs;
  final String? lastCompletedSeriesId;
  final int? lastCompletedAtMs;

  DateTime? get firstSecretOwnedAt => firstSecretOwnedAtMs == null
      ? null
      : DateTime.fromMillisecondsSinceEpoch(firstSecretOwnedAtMs!);

  DateTime? get lastCompletedAt => lastCompletedAtMs == null
      ? null
      : DateTime.fromMillisecondsSinceEpoch(lastCompletedAtMs!);
}

/// Local prefs backing for shelf memory moments.
final class CollectionMemoryStore {
  CollectionMemoryStore._();

  static final CollectionMemoryStore instance = CollectionMemoryStore._();

  static const _prefsKey = 'collection_memory_v1';

  CollectionMemoryData _cached = const CollectionMemoryData();
  bool _loaded = false;

  CollectionMemoryData get cached {
    if (!_loaded) return const CollectionMemoryData();
    return _cached;
  }

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final m = jsonDecode(raw) as Map<String, dynamic>;
        _cached = CollectionMemoryData(
          firstSecretOwnedAtMs: m['firstSecretOwnedAtMs'] as int?,
          lastCompletedSeriesId: m['lastCompletedSeriesId'] as String?,
          lastCompletedAtMs: m['lastCompletedAtMs'] as int?,
        );
      } catch (_) {
        _cached = const CollectionMemoryData();
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

    if (data.firstSecretOwnedAtMs == null && _hasOwnedSecret(next)) {
      data = CollectionMemoryData(
        firstSecretOwnedAtMs: now,
        lastCompletedSeriesId: data.lastCompletedSeriesId,
        lastCompletedAtMs: data.lastCompletedAtMs,
      );
      changed = true;
    }

    for (final series in next.shelfSeries) {
      if (!_wasSeriesComplete(previous, series.id) &&
          _isSeriesComplete(next, series.id)) {
        data = CollectionMemoryData(
          firstSecretOwnedAtMs: data.firstSecretOwnedAtMs,
          lastCompletedSeriesId: series.id,
          lastCompletedAtMs: now,
        );
        changed = true;
        break;
      }
    }

    if (changed) {
      _cached = data;
      await _persist();
    }
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _prefsKey,
      jsonEncode({
        'firstSecretOwnedAtMs': _cached.firstSecretOwnedAtMs,
        'lastCompletedSeriesId': _cached.lastCompletedSeriesId,
        'lastCompletedAtMs': _cached.lastCompletedAtMs,
      }),
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
