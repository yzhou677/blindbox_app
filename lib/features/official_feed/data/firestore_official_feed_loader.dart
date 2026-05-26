import 'package:blindbox_app/core/firebase/ensure_firebase_initialized.dart';
import 'package:blindbox_app/features/official_feed/data/official_feed_mapper.dart';
import 'package:blindbox_app/features/official_feed/domain/official_feed_item.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

const String kOfficialFeedCollection = 'official_feed_items';

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

  final items = <OfficialFeedItem>[];
  for (final doc in snap.docs) {
    final mapped = mapOfficialFeedItem(doc.id, doc.data());
    if (mapped != null) {
      items.add(mapped);
    }
  }
  return items;
}
