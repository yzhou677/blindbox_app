import 'package:blindbox_app/features/collection/data/collection_seed_data.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';

/// Holds the first [CollectionSnapshot] for the app session (from disk or seed).
///
/// [prime] is called from `main` after [CollectionSnapshotStorage.load]; the
/// [CollectionNotifier] consumes it once in [takeInitialSnapshot].
abstract final class CollectionAppBootstrap {
  static CollectionSnapshot? _primed;

  /// Set before `runApp` when local restore succeeds, or fallback to seed.
  static void prime(CollectionSnapshot snapshot) {
    _primed = snapshot;
  }

  /// Single-use initial state for [CollectionNotifier.build].
  static CollectionSnapshot takeInitialSnapshot() {
    final s = _primed ?? CollectionSeedData.initialSnapshot();
    _primed = null;
    return s;
  }
}
