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

  if (kDebugMode) {
    // Force native debug-provider initialization during startup. Android's
    // DebugAppCheckProvider prints its local registration secret to logcat.
    // Never print the returned App Check JWT or the secret from Dart.
    debugPrint(
      '[AppCheck] Debug provider active. Look for the native '
      'DebugAppCheckProvider registration message in logcat.',
    );
    try {
      await FirebaseAppCheck.instance.getToken(true);
      debugPrint('[AppCheck] Debug token exchange succeeded.');
    } on FirebaseException catch (error) {
      debugPrint(
        '[AppCheck] Debug token exchange failed '
        '(code=${error.code}, message=${error.message}). '
        'Register the DebugAppCheckProvider secret in Firebase Console.',
      );
    } catch (error) {
      debugPrint(
        '[AppCheck] Debug token exchange failed (${error.runtimeType}). '
        'Register the DebugAppCheckProvider secret in Firebase Console.',
      );
    }
  }
}
