import 'package:blindbox_app/core/firebase/ensure_firebase_initialized.dart';
import 'package:blindbox_app/features/official_feed/data/official_feed_mapper.dart';
import 'package:blindbox_app/features/official_feed/domain/official_feed_item.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

const String kOfficialFeedCollection = 'official_feed_items';

/// Keeps first occurrence of each stable feed [OfficialFeedItem.id].
///
/// Dedup is **per source list** (one Firestore query). Document ids are globally
/// unique in production (`official_feed_items/{id}`), so cross-brand id collision
/// is a seed error, not a runtime merge.
List<OfficialFeedItem> dedupeOfficialFeedItemsById(
  Iterable<OfficialFeedItem> items,
) {
  final seen = <String>{};
  final out = <OfficialFeedItem>[];
  for (final item in items) {
    if (seen.add(item.id)) {
      out.add(item);
    }
  }
  return out;
}

/// Maps docs one-by-one; invalid rows are skipped (never fail the whole source).
List<OfficialFeedItem> mapOfficialFeedDocuments(
  Iterable<({String id, Map<String, dynamic> data})> docs,
) {
  final mapped = <OfficialFeedItem>[];
  for (final doc in docs) {
    final item = mapOfficialFeedItem(doc.id, doc.data);
    if (item != null) {
      mapped.add(item);
    }
  }
  return dedupeOfficialFeedItemsById(mapped);
}

/// One-shot Firestore read for active official feed items (newest first).
Future<List<OfficialFeedItem>> loadFirestoreOfficialFeed({
  required String sourceId,
  int limit = 12,
  FirebaseFirestore? firestore,
}) async {
  await ensureFirebaseInitialized();
  final db = firestore ?? FirebaseFirestore.instance;

  final snap = await db
      .collection(kOfficialFeedCollection)
      .where('sourceId', isEqualTo: sourceId)
      .where('status', isEqualTo: 'active')
      .orderBy('publishedAt', descending: true)
      .limit(limit)
      .get();

  return mapOfficialFeedDocuments([
    for (final doc in snap.docs) (id: doc.id, data: doc.data()),
  ]);
}
