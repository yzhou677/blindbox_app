import 'package:flutter/foundation.dart';

/// Canonical debug log prefixes for tab/feature render pipelines.
///
/// Grep logcat or Android Studio for **`Pipeline`** to surface every pipeline
/// profiler in one view, or narrow with e.g. `CollectionPipeline [search]`.
///
/// Planned / adopted prefixes:
/// - [collection] — Collection shelf browse (`CollectionShelfPipelineTrace`)
/// - [catalogSearch] — shared Search V2 (`CatalogSearchPipelineTrace`)
/// - [market] — Market browse/search (future `MarketPipeline`; legacy: `MarketSearch`)
/// - [discover] — Discover home rails
/// - [feed] — Home feed assembly
abstract final class AppPipelinePrefix {
  static const collection = 'CollectionPipeline';
  static const catalogSearch = 'CatalogSearchPipeline';
  static const market = 'MarketPipeline';
  static const discover = 'DiscoverPipeline';
  static const feed = 'FeedPipeline';
}

/// Shared debug-only pipeline log line formatter.
///
/// Profile/release: all methods no-op except [formatMicros].
abstract final class AppPipelineLog {
  static final Map<String, int> _runSeq = {};

  /// Monotonic run id per [prefix] (e.g. `CollectionPipeline #12`).
  static int nextRun(String prefix) {
    final next = (_runSeq[prefix] ?? 0) + 1;
    _runSeq[prefix] = next;
    return next;
  }

  /// `CollectionPipeline #12 [search] 4.0ms`
  static void line(String prefix, int run, String tag, String message) {
    if (!kDebugMode) return;
    debugPrint('$prefix #$run [$tag] $message');
  }

  /// Human-readable duration for pipeline stage lines.
  static String formatMicros(int micros) {
    if (micros < 1000) return '${micros}us';
    final ms = micros / 1000;
    if (ms < 10) return '${ms.toStringAsFixed(1)}ms';
    return '${ms.round()}ms';
  }

  /// Default single-frame UI budget for `[warn] exceeded` lines.
  static const int frameBudgetMs = 16;
}
