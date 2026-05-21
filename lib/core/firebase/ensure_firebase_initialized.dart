import 'package:blindbox_app/firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';

/// Initializes the default Firebase app once. Safe to call multiple times.
///
/// Collection/shelf code does not use this — only remote catalog entry points
/// (e.g. [loadFirestoreCatalogBundle]) should call it when needed.
Future<void> ensureFirebaseInitialized() async {
  if (Firebase.apps.isNotEmpty) {
    return;
  }
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}
