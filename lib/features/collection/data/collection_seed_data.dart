import 'package:blindbox_app/features/collection/domain/collection_domain.dart';

/// Initial shelf snapshot when no persisted data exists.
///
/// Important product rule: first install must start with an empty personal
/// shelf. Demo/sample rows should only appear in tests or explicit preview
/// tools, never as fallback runtime data for real users.
abstract final class CollectionSeedData {
  static CollectionSnapshot initialSnapshot() => CollectionSnapshot.emptyTest();
}
