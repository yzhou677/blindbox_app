import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Asks Android [BackupManager] to note that Auto Backup data changed.
///
/// iOS / missing plugins: invoke fails quietly (logged only).
abstract final class AndroidBackupNotifier {
  AndroidBackupNotifier._();

  static const MethodChannel channel = MethodChannel(
    'app.shelfy.collector/android_backup',
  );

  static const methodDataChanged = 'dataChanged';

  /// Test hook: when set, used instead of [channel].
  @visibleForTesting
  static Future<void> Function()? testNotifyOverride;

  /// Best-effort notify. Never throws to callers.
  static Future<void> notifyDataChanged() async {
    if (kIsWeb) return;
    final override = testNotifyOverride;
    if (override != null) {
      try {
        await override();
      } catch (e, st) {
        debugPrint('AndroidBackupNotifier.dataChanged override failed: $e\n$st');
      }
      return;
    }
    try {
      await channel.invokeMethod<void>(methodDataChanged);
    } catch (e, st) {
      debugPrint('AndroidBackupNotifier.dataChanged failed: $e\n$st');
    }
  }

  @visibleForTesting
  static void resetForTest() {
    testNotifyOverride = null;
  }
}
