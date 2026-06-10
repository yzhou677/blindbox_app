import 'package:flutter/foundation.dart';

/// Debug timeline for Market search ANR investigation (filter logcat: MarketSearch).
abstract final class MarketSearchTrace {
  static final Stopwatch _clock = Stopwatch()..start();
  static int _seq = 0;
  static int _lastEventMs = 0;
  static int _lastBuildTraceMs = 0;
  static int _buildBurstCount = 0;

  static void event(
    String message, {
    int? listings,
    String? signature,
    int? gapWarnMs,
  }) {
    if (!kDebugMode) return;
    final now = _clock.elapsedMilliseconds;
    final id = ++_seq;
    final gap = now - _lastEventMs;
    _lastEventMs = now;
    final parts = <String>[
      '[MarketSearch +${now}ms gap=${gap}ms #$id]',
      message,
    ];
    if (listings != null) parts.add('listings=$listings');
    if (signature != null) parts.add('sig=$signature');
    debugPrint(parts.join(' '));
    if (gapWarnMs != null && gap >= gapWarnMs) {
      debugPrint(
        '[MarketSearch +${now}ms] *** GAP ${gap}ms since previous event ***',
      );
    }
  }

  /// High-frequency widget rebuild tracing without logcat floods.
  ///
  /// Logs when the screen idles/resumes, stalls, or enters a rapid rebuild burst
  /// (sampled every [sampleEvery] frames during bursts).
  static void buildEvent(
    String message, {
    int stormGapMs = 32,
    int slowGapMs = 250,
    int idleGapMs = 500,
    int sampleEvery = 120,
  }) {
    if (!kDebugMode) return;
    final now = _clock.elapsedMilliseconds;
    final gap = _lastBuildTraceMs == 0 ? idleGapMs : now - _lastBuildTraceMs;
    _lastBuildTraceMs = now;

    final inBurst = gap <= stormGapMs;
    if (inBurst) {
      _buildBurstCount++;
    } else {
      if (_buildBurstCount >= sampleEvery) {
        event(
          '$message [burst ended after $_buildBurstCount rebuilds]',
          gapWarnMs: slowGapMs,
        );
      }
      _buildBurstCount = 1;
    }

    final shouldLog = gap >= idleGapMs ||
        gap >= slowGapMs ||
        (inBurst && (_buildBurstCount == 1 || _buildBurstCount % sampleEvery == 0));

    if (!shouldLog) return;

    final tag = gap >= slowGapMs
        ? 'slow'
        : gap >= idleGapMs
            ? 'idle'
            : 'burst';
    event('$message [$tag gap=${gap}ms n=$_buildBurstCount]');
  }

  /// Wraps synchronous UI-isolate work; always logs start/end and flags slow runs.
  static T sync<T>(
    String label,
    T Function() action, {
    int warnMs = 8,
  }) {
    if (!kDebugMode) return action();
    event('$label START');
    final sw = Stopwatch()..start();
    final result = action();
    final elapsed = sw.elapsedMilliseconds;
    if (elapsed >= warnMs) {
      event('$label END BLOCKED ${elapsed}ms on UI thread', gapWarnMs: 1000);
    } else {
      event('$label END ${elapsed}ms sync');
    }
    return result;
  }

  static Future<T> asyncSection<T>(
    String label,
    Future<T> Function() action, {
    int gapWarnMs = 1000,
  }) async {
    if (!kDebugMode) return action();
    event('$label START (async)');
    final sw = Stopwatch()..start();
    final result = await action();
    final elapsed = sw.elapsedMilliseconds;
    event(
      '$label END ${elapsed}ms async',
      gapWarnMs: gapWarnMs,
    );
    return result;
  }
}
