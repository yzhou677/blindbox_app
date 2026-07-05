import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// One global Master Complete achievement overlay request.
@immutable
class MasterCompleteCelebrationEvent {
  const MasterCompleteCelebrationEvent({required this.token});

  /// Monotonic id so repeat earns on the same series re-trigger the overlay.
  final int token;
}

/// Queues and presents app-wide Master Complete achievement overlays.
final masterCompleteCelebrationProvider =
    NotifierProvider<MasterCompleteCelebrationNotifier,
        MasterCompleteCelebrationEvent?>(
  MasterCompleteCelebrationNotifier.new,
);

class MasterCompleteCelebrationNotifier
    extends Notifier<MasterCompleteCelebrationEvent?> {
  var _queued = 0;
  var _token = 0;
  var _presenting = false;

  @visibleForTesting
  bool get isPresenting => _presenting;

  @visibleForTesting
  int get queuedCount => _queued;

  @override
  MasterCompleteCelebrationEvent? build() => null;

  void celebrate() {
    if (_presenting || state != null) {
      _queued++;
      return;
    }
    _emit();
  }

  /// Called by the host after the overlay entry is inserted successfully.
  void onPresentationStarted() {
    _presenting = true;
  }

  /// Called by the overlay host when the current presentation finishes.
  void onPresentationFinished() {
    _presenting = false;
    state = null;
    _dequeueNext();
  }

  /// Called when overlay insertion fails after retries — skip current, drain queue.
  void onPresentationFailed() {
    _presenting = false;
    state = null;
    _dequeueNext();
  }

  void _dequeueNext() {
    if (_queued == 0) return;
    _queued--;
    _emit();
  }

  void _emit() {
    _token++;
    state = MasterCompleteCelebrationEvent(token: _token);
  }
}
