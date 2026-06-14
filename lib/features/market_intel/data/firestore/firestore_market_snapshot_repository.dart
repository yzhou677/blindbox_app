import 'package:blindbox_app/core/firebase/ensure_firebase_initialized.dart';
import 'package:blindbox_app/features/market_intel/data/firestore/firestore_market_snapshot_mapper.dart';
import 'package:blindbox_app/features/market_intel/domain/market_snapshot.dart';
import 'package:blindbox_app/features/market_intel/domain/market_snapshot_repository.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class FirestoreMarketSnapshotRepository implements MarketSnapshotRepository {
  FirestoreMarketSnapshotRepository({FirebaseFirestore? firestore})
      : _firestore = firestore;

  final FirebaseFirestore? _firestore;

  FirebaseFirestore get _db => _firestore ?? FirebaseFirestore.instance;

  @override
  Future<MarketSnapshot?> getSnapshotForFigure(String figureId) async {
    final id = figureId.trim();
    if (id.isEmpty) return null;

    try {
      await ensureFirebaseInitialized();
      final snap = await _db.collection(kMarketSnapshotsCollection).doc(id).get();
      if (!snap.exists) return null;
      final data = snap.data();
      if (data == null) return null;
      return mapFirestoreMarketSnapshot(snap.id, data);
    } on Object catch (e, st) {
      debugPrint(
        'FirestoreMarketSnapshotRepository.getSnapshotForFigure($id): $e\n$st',
      );
      return null;
    }
  }

  @override
  Future<MarketSnapshot?> getSnapshotForSeries(String seriesId) async {
    final id = seriesId.trim();
    if (id.isEmpty) return null;

    try {
      await ensureFirebaseInitialized();
      final snap = await _db.collection(kMarketSnapshotsCollection).doc(id).get();
      if (!snap.exists) return null;
      final data = snap.data();
      if (data == null) return null;
      return mapFirestoreMarketSnapshot(snap.id, data);
    } on Object catch (e, st) {
      debugPrint(
        'FirestoreMarketSnapshotRepository.getSnapshotForSeries($id): $e\n$st',
      );
      return null;
    }
  }

  @override
  Future<List<MarketSnapshot>> getSnapshotsForSeries(String seriesId) async {
    final id = seriesId.trim();
    if (id.isEmpty) return const [];

    try {
      await ensureFirebaseInitialized();
      final snap = await _db
          .collection(kMarketSnapshotsCollection)
          .where('seriesId', isEqualTo: id)
          .where('level', isEqualTo: 'figure')
          .get();

      final out = <MarketSnapshot>[];
      for (final doc in snap.docs) {
        final mapped = mapFirestoreMarketSnapshot(doc.id, doc.data());
        if (mapped != null) out.add(mapped);
      }
      return out;
    } on Object catch (e, st) {
      debugPrint(
        'FirestoreMarketSnapshotRepository.getSnapshotsForSeries($id): $e\n$st',
      );
      return const [];
    }
  }
}
