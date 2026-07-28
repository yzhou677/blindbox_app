import 'dart:async';

/// Debounce durations for **committed** search queries — not TextField text.
///
/// The field must always update immediately via its [TextEditingController].
/// Only result computation / remote queries should wait on these policies.
abstract final class SearchCommitPolicy {
  /// Tiny in-memory filters — commit on every change.
  static const Duration immediate = Duration.zero;

  /// Shared delay for all local (in-process) committed searches.
  static const Duration local = Duration(milliseconds: 250);

  /// Local full-catalog scan (Discover / Add Series).
  static const Duration localCatalog = local;

  /// Local shelf / wishlist filtering.
  static const Duration localCollection = local;

  /// Network-backed browse (Market).
  static const Duration remote = Duration(milliseconds: 400);
}

/// Lifecycle-safe scheduler that commits the latest query after [delay].
///
/// - Empty queries commit **immediately** (clear must not wait).
/// - Rapid typing resets the timer; only the latest value is published.
/// - [dispose] cancels any pending timer.
final class SearchCommitScheduler {
  SearchCommitScheduler({
    required this.delay,
    required void Function(String query) onCommit,
  }) : _onCommit = onCommit;

  final Duration delay;
  final void Function(String query) _onCommit;

  Timer? _timer;
  String? _pending;
  bool _disposed = false;

  /// Schedule a commit for [query], replacing any pending commit.
  void schedule(String query) {
    if (_disposed) return;
    _pending = query;
    _timer?.cancel();
    if (delay == Duration.zero || query.trim().isEmpty) {
      _flush();
      return;
    }
    _timer = Timer(delay, _flush);
  }

  /// Commit [query] immediately (submit, history tap, programmatic apply).
  void commitNow(String query) {
    if (_disposed) return;
    _pending = query;
    _timer?.cancel();
    _flush();
  }

  /// Cancel a pending commit without publishing.
  void cancel() {
    _timer?.cancel();
    _timer = null;
    _pending = null;
  }

  void dispose() {
    _disposed = true;
    cancel();
  }

  void _flush() {
    _timer = null;
    final q = _pending;
    _pending = null;
    if (q == null || _disposed) return;
    _onCommit(q);
  }
}
