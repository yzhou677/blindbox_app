// GENERATED PLACEHOLDER — replace by running:
//   dart pub global activate flutterfire_cli
//   flutterfire configure
//
// This file must exist so the project compiles before FlutterFire is run.
// Use your real Firebase project's keys and IDs in [DefaultFirebaseOptions].

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

/// Default [FirebaseOptions] for use with [Firebase.initializeApp].
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.fuchsia:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not configured for $defaultTargetPlatform. '
          'Run `flutterfire configure` or use an Android/iOS/macOS/Web target for Firestore.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'CONFIGURE_WEB_API_KEY',
    appId: 'CONFIGURE_WEB_APP_ID',
    messagingSenderId: 'CONFIGURE_SENDER_ID',
    projectId: 'configure-your-project-id',
    authDomain: 'configure-your-project-id.firebaseapp.com',
    storageBucket: 'configure-your-project-id.appspot.com',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'CONFIGURE_ANDROID_API_KEY',
    appId: 'CONFIGURE_ANDROID_APP_ID',
    messagingSenderId: 'CONFIGURE_SENDER_ID',
    projectId: 'configure-your-project-id',
    storageBucket: 'configure-your-project-id.appspot.com',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'CONFIGURE_IOS_API_KEY',
    appId: 'CONFIGURE_IOS_APP_ID',
    messagingSenderId: 'CONFIGURE_SENDER_ID',
    projectId: 'configure-your-project-id',
    storageBucket: 'configure-your-project-id.appspot.com',
    iosBundleId: 'com.example.blindboxApp',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'CONFIGURE_MACOS_API_KEY',
    appId: 'CONFIGURE_MACOS_APP_ID',
    messagingSenderId: 'CONFIGURE_SENDER_ID',
    projectId: 'configure-your-project-id',
    storageBucket: 'configure-your-project-id.appspot.com',
    iosBundleId: 'com.example.blindboxApp',
  );
}
