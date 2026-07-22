import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';

/// Activates mobile App Check before protected callable Functions are used.
///
/// Web is intentionally not configured: Shelfy's locator transport is mobile
/// only until a web attestation provider and site key are explicitly adopted.
Future<void> activateFirebaseAppCheck() async {
  if (kIsWeb) return;
  await FirebaseAppCheck.instance.activate(
    providerAndroid: kDebugMode
        ? const AndroidDebugProvider()
        : const AndroidPlayIntegrityProvider(),
    providerApple: kDebugMode
        ? const AppleDebugProvider()
        : const AppleAppAttestWithDeviceCheckFallbackProvider(),
  );
}
