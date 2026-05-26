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
    // TODO(perf/scale): CollectionSnapshotCodec.tryDecode runs jsonDecode of
    // the full shelf JSON on the UI isolate during startup.  Move to
    // Isolate.run before runApp when cold-start time becomes measurable on
    // large shelves (rough threshold: >500 figures or >200 ms on target device).
    return CollectionSnapshotCodec.tryDecode(raw);
  }

  static Future<void> save(CollectionSnapshot snapshot) async {
    // TODO(perf/scale): CollectionSnapshotCodec.encode runs jsonEncode of the
    // entire shelf on the UI isolate.  At indie scale (≤100 series, ≤1000
    // figures) this is typically <50 ms.  If shelf sizes grow significantly,
    // move the encode step to Isolate.run / compute() before the prefs write.
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, CollectionSnapshotCodec.encode(snapshot));
  }
}
