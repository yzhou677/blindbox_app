import 'package:flutter/foundation.dart';

/// TEMP DEBUG — correlates every log line belonging to one [requestReveal].
///
/// Do not use for product logic.
abstract final class CollectorTypeRevealTrace {
  CollectorTypeRevealTrace._();

  static String? activeTraceId;

  /// Set true only after Stage 5 so provider/Hero rebuilds during analyzing
  /// do not pollute the ordered stage sequence.
  static bool emitProviderHero = false;

  static void begin(String traceId) {
    activeTraceId = traceId;
    emitProviderHero = false;
  }

  static void log(String stage, String message) {
    final id = activeTraceId;
    final line = id == null
        ? '[CT_TRACE] NO_TRACE_ID stage=$stage $message'
        : '[CT_TRACE] traceId=$id stage=$stage $message';
    // print() is more reliable than debugPrint on some Android logcat filters.
    // ignore: avoid_print
    print(line);
    debugPrint(line);
  }
}
