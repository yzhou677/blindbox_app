import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/collection/persistence/collection_snapshot_codec.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Durable local key/value persistence for [CollectionSnapshot] (offline-first).
abstract final class CollectionSnapshotStorage {
  static const _prefsKey = 'collection_snapshot_v1';

  static Future<CollectionSnapshot?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null || raw.isEmpty) return null;
    return CollectionSnapshotCodec.tryDecode(raw);
  }

  static Future<void> save(CollectionSnapshot snapshot) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, CollectionSnapshotCodec.encode(snapshot));
  }
}
