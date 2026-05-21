// Template — copy to `lib/firebase_options.dart` and fill from Firebase console
// or run `flutterfire configure`.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

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
          'DefaultFirebaseOptions are not configured for $defaultTargetPlatform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'CONFIGURE_WEB_API_KEY',
    appId: 'CONFIGURE_WEB_APP_ID',
    messagingSenderId: 'CONFIGURE_SENDER_ID',
    projectId: 'your-project-id',
    authDomain: 'your-project-id.firebaseapp.com',
    storageBucket: 'your-project-id.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'CONFIGURE_ANDROID_API_KEY',
    appId: 'CONFIGURE_ANDROID_APP_ID',
    messagingSenderId: 'CONFIGURE_SENDER_ID',
    projectId: 'your-project-id',
    storageBucket: 'your-project-id.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'CONFIGURE_IOS_API_KEY',
    appId: 'CONFIGURE_IOS_APP_ID',
    messagingSenderId: 'CONFIGURE_SENDER_ID',
    projectId: 'your-project-id',
    storageBucket: 'your-project-id.firebasestorage.app',
    iosBundleId: 'com.example.blindboxApp',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'CONFIGURE_MACOS_API_KEY',
    appId: 'CONFIGURE_MACOS_APP_ID',
    messagingSenderId: 'CONFIGURE_SENDER_ID',
    projectId: 'your-project-id',
    storageBucket: 'your-project-id.firebasestorage.app',
    iosBundleId: 'com.example.blindboxApp',
  );
}
