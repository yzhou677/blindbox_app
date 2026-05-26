import 'package:blindbox_app/features/official_feed/data/official_feed_repository.dart';
import 'package:blindbox_app/features/official_feed/domain/official_feed_item.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final officialFeedRepositoryProvider = Provider<OfficialFeedRepository>(
  (ref) => OfficialFeedRepository(),
);

/// POP MART US editorial rail for Home — empty list on failure (section hides).
final officialFeedListProvider = FutureProvider<List<OfficialFeedItem>>((ref) async {
  final repo = ref.watch(officialFeedRepositoryProvider);
  return repo.loadPopMartUs(limit: 12);
});
