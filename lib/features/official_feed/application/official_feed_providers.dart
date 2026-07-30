import 'package:blindbox_app/features/official_feed/data/official_feed_repository.dart';
import 'package:blindbox_app/features/official_feed/domain/official_feed_catalog.dart';
import 'package:blindbox_app/features/official_feed/domain/official_feed_item.dart';
import 'package:blindbox_app/features/official_feed/domain/official_feed_sources.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final officialFeedRepositoryProvider = Provider<OfficialFeedRepository>(
  (ref) => OfficialFeedRepository(),
);

/// All curated Home brands (empty list per brand when Firestore has no docs).
final officialFeedCatalogProvider = FutureProvider<OfficialFeedCatalog>((
  ref,
) async {
  final repo = ref.watch(officialFeedRepositoryProvider);
  return repo.loadCuratedHomeCatalog(limitPerSource: 12);
});

/// Session selection for the Home brand filter chips.
final officialFeedSelectedSourceProvider =
    NotifierProvider<OfficialFeedSelectedSourceNotifier, String>(
      OfficialFeedSelectedSourceNotifier.new,
    );

class OfficialFeedSelectedSourceNotifier extends Notifier<String> {
  @override
  String build() => OfficialFeedSources.popmartUs;

  void select(String sourceId) {
    if (!OfficialFeedSources.curatedHomeSources.contains(sourceId)) return;
    if (state == sourceId) return;
    state = sourceId;
  }
}

/// Visible Home rail for the resolved brand (chips or single-source fallback).
final officialFeedListProvider = FutureProvider<List<OfficialFeedItem>>((
  ref,
) async {
  final catalog = await ref.watch(officialFeedCatalogProvider.future);
  final preferred = ref.watch(officialFeedSelectedSourceProvider);
  final sourceId = OfficialFeedSources.resolveSelection(
    availableSourceIds: catalog.availableSources,
    preferred: preferred,
  );
  if (sourceId == null) return const [];
  return catalog.itemsFor(sourceId);
});
