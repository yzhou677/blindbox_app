import 'package:blindbox_app/core/debug/app_pipeline_log.dart';
import 'package:flutter/foundation.dart';

/// Debug-only timing for [CatalogSearchService] public entry points.
///
/// Log prefix: [AppPipelinePrefix.catalogSearch] (`CatalogSearchPipeline`).
/// Filter logcat: `Pipeline` · `CatalogSearchPipeline` · `CatalogSearchPipeline [warn]`.
///
/// No-op in profile/release builds.
abstract final class CatalogSearchPipelineTrace {
  static const _prefix = AppPipelinePrefix.catalogSearch;
  static const int slowSearchMs = 50;

  /// Times [action], logs one run, returns the result unchanged.
  static T run<T>({
    required String rawQuery,
    required int catalogSeries,
    required int catalogFigures,
    required T Function() action,
    required String Function(T result) resultLine,
  }) {
    if (!kDebugMode) return action();

    final sw = Stopwatch()..start();
    final result = action();
    sw.stop();

    final run = AppPipelineLog.nextRun(_prefix);
    final micros = sw.elapsedMicroseconds;
    final totalMs = sw.elapsedMilliseconds;

    AppPipelineLog.line(_prefix, run, 'total', AppPipelineLog.formatMicros(micros));
    AppPipelineLog.line(_prefix, run, 'query', _formatQuery(rawQuery));
    AppPipelineLog.line(
      _prefix,
      run,
      'catalog',
      'series=$catalogSeries figures=$catalogFigures',
    );
    AppPipelineLog.line(_prefix, run, 'result', resultLine(result));

    if (totalMs >= slowSearchMs) {
      AppPipelineLog.line(
        _prefix,
        run,
        'warn',
        'exceeded ${slowSearchMs}ms (${totalMs}ms)',
      );
    }

    return result;
  }

  static String _formatQuery(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return '""';
    return '"${trimmed.replaceAll('"', r'\"')}"';
  }
}
