import 'package:blindbox_app/core/firebase/ensure_firebase_initialized.dart';
import 'package:blindbox_app/features/ip_profile/data/ip_profile_mapper.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Raw document read used by [IpProfileRepository] (testable without Firebase).
class IpProfileRemoteDocument {
  const IpProfileRemoteDocument({
    required this.documentId,
    required this.exists,
    required this.isFromCache,
    required this.data,
  });

  final String documentId;
  final bool exists;
  final bool isFromCache;
  final Map<String, dynamic>? data;
}

abstract class IpProfileDocumentSource {
  Future<IpProfileRemoteDocument> fetch(
    String ipId, {
    required bool preferServer,
  });
}

class FirestoreIpProfileDocumentSource implements IpProfileDocumentSource {
  FirestoreIpProfileDocumentSource({
    FirebaseFirestore? firestore,
    Duration timeout = const Duration(seconds: 8),
  }) : _firestore = firestore,
       _timeout = timeout;

  final FirebaseFirestore? _firestore;
  final Duration _timeout;

  @override
  Future<IpProfileRemoteDocument> fetch(
    String ipId, {
    required bool preferServer,
  }) async {
    await ensureFirebaseInitialized();
    final db = _firestore ?? FirebaseFirestore.instance;
    final docRef = db.collection(kIpProfilesCollection).doc(ipId);
    final snap = preferServer
        ? await docRef
              .get(const GetOptions(source: Source.server))
              .timeout(_timeout)
        : await docRef.get().timeout(_timeout);
    return IpProfileRemoteDocument(
      documentId: snap.id,
      exists: snap.exists,
      isFromCache: snap.metadata.isFromCache,
      data: snap.data(),
    );
  }
}
