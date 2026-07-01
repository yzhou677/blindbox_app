import 'package:blindbox_app/core/debug/app_pipeline_log.dart';
import 'package:flutter/foundation.dart';

/// Debug-only timing for [CollectionScreen] browse pipeline.
///
/// Log prefix: [AppPipelinePrefix.collection] (`CollectionPipeline`).
/// Filter logcat: `Pipeline` (all tabs) · `CollectionPipeline [search]` ·
/// `CollectionPipeline [warn]` · `CollectionPipeline #12`.
///
/// No-op in profile/release builds — zero overhead on shipped apps.
abstract final class CollectionShelfPipelineTrace {
  static CollectionShelfPipelineTraceScope start() {
    if (!kDebugMode) return const CollectionShelfPipelineTraceScope.noop();
    return CollectionShelfPipelineTraceScope.live();
  }
}

/// Per-build profiler scope. Call [section] / [sectionVoid] around pipeline
/// stages, then [finish] once before returning from `build`.
final class CollectionShelfPipelineTraceScope {
  const CollectionShelfPipelineTraceScope.noop() : _live = null;

  CollectionShelfPipelineTraceScope.live()
      : _live = _LiveCollectionShelfPipelineTrace();

  final _LiveCollectionShelfPipelineTrace? _live;

  /// Times [action] and records [label] (e.g. `Search`, `Sort`).
  T section<T>(String label, T Function() action) {
    final live = _live;
    if (live == null) return action();
    return live._section(label, action);
  }

  /// Like [section] for stages that assign multiple locals via closure.
  void sectionVoid(String label, void Function() action) {
    section<Object?>(label, () {
      action();
      return null;
    });
  }

  /// Logs timing breakdown plus catalog/shelf sizes for remote diagnosis.
  void finish({
    required int shelfSeries,
    int? visibleSeries,
    int? catalogSeries,
    int? catalogFigures,
    String? note,
  }) {
    _live?.finish(
      shelfSeries: shelfSeries,
      visibleSeries: visibleSeries,
      catalogSeries: catalogSeries,
      catalogFigures: catalogFigures,
      note: note,
    );
  }
}

final class _LiveCollectionShelfPipelineTrace {
  static const _prefix = AppPipelinePrefix.collection;

  /// Single-frame UI budget — warn when total pipeline exceeds this in debug.
  static const int frameBudgetMs = AppPipelineLog.frameBudgetMs;

  /// Search-only threshold for an explicit slow-search warning.
  static const int slowSearchMs = 150;

  final Stopwatch _total = Stopwatch()..start();
  final Map<String, int> _micros = {};

  static const _order = [
    'Insights',
    'Filter',
    'Search',
    'Partition',
    'Sort',
    'Feed',
    'Summary',
  ];

  static const _stageTags = {
    'Insights': 'insights',
    'Filter': 'filter',
    'Search': 'search',
    'Partition': 'partition',
    'Sort': 'sort',
    'Feed': 'feed',
    'Summary': 'summary',
  };

  T _section<T>(String label, T Function() action) {
    final sw = Stopwatch()..start();
    try {
      return action();
    } finally {
      sw.stop();
      _micros[label] = (_micros[label] ?? 0) + sw.elapsedMicroseconds;
    }
  }

  void finish({
    required int shelfSeries,
    int? visibleSeries,
    int? catalogSeries,
    int? catalogFigures,
    String? note,
  }) {
    _total.stop();
    final run = AppPipelineLog.nextRun(_prefix);
    final totalMs = _total.elapsedMilliseconds;
    final seriesToken = catalogSeries?.toString() ?? '-';
    final figuresToken = catalogFigures?.toString() ?? '-';
    final visibleToken = visibleSeries?.toString() ?? '-';
    final noteSuffix = note == null ? '' : ' ($note)';

    _log(run, 'total', '${totalMs}ms$noteSuffix');
    _log(
      run,
      'size',
      'series=$seriesToken figures=$figuresToken shelf=$shelfSeries visible=$visibleToken',
    );

    for (final label in _order) {
      final micros = _micros[label];
      if (micros == null) continue;
      final tag = _stageTags[label] ?? label.toLowerCase();
      _log(run, tag, AppPipelineLog.formatMicros(micros));
    }
    for (final entry in _micros.entries) {
      if (_order.contains(entry.key)) continue;
      _log(run, entry.key.toLowerCase(), AppPipelineLog.formatMicros(entry.value));
    }

    _emitSlowWarnings(run, totalMs);
  }

  void _emitSlowWarnings(int run, int totalMs) {
    final searchMicros = _micros['Search'];
    final searchMs = searchMicros == null ? 0 : searchMicros / 1000;

    if (searchMs >= slowSearchMs) {
      _log(
        run,
        'warn',
        'slow Search: ${AppPipelineLog.formatMicros(searchMicros!)}',
      );
    }

    if (totalMs < frameBudgetMs) return;

    _log(run, 'warn', 'exceeded ${frameBudgetMs}ms (${totalMs}ms)');

    final slowest = _slowestStage();
    if (slowest == null) return;
    if (slowest.$1 == 'Search' && searchMs >= slowSearchMs) return;
    final tag = _stageTags[slowest.$1] ?? slowest.$1.toLowerCase();
    _log(run, 'warn', 'slowest [$tag]: ${AppPipelineLog.formatMicros(slowest.$2)}');
  }

  (String, int)? _slowestStage() {
    if (_micros.isEmpty) return null;
    var bestLabel = '';
    var bestMicros = 0;
    for (final entry in _micros.entries) {
      if (entry.value > bestMicros) {
        bestMicros = entry.value;
        bestLabel = entry.key;
      }
    }
    if (bestMicros <= 0) return null;
    return (bestLabel, bestMicros);
  }

  static void _log(int run, String tag, String message) {
    AppPipelineLog.line(_prefix, run, tag, message);
  }
}
