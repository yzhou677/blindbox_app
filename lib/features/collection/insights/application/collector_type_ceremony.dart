import 'package:blindbox_app/features/collection/insights/domain/collector_type_identity.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// One-shot Collector Type reveal ceremony — separate from hero card state.
@immutable
final class CollectorTypeCeremonyEvent {
  const CollectorTypeCeremonyEvent({
    required this.token,
    required this.identity,
    required this.isFirstReveal,
  });

  final int token;
  final CollectorTypeIdentity identity;

  /// `true` for the very first reveal; `false` for a collector-type change.
  final bool isFirstReveal;
}

/// Presentation queue for the reveal ceremony overlay.
final class CollectorTypeCeremonyController
    extends Notifier<CollectorTypeCeremonyEvent?> {
  var _token = 0;
  var _presenting = false;

  @override
  CollectorTypeCeremonyEvent? build() => null;

  /// Enqueues a ceremony. No-op while another is presenting.
  void present({
    required CollectorTypeIdentity identity,
    required bool isFirstReveal,
  }) {
    if (_presenting) return;
    _token += 1;
    state = CollectorTypeCeremonyEvent(
      token: _token,
      identity: identity,
      isFirstReveal: isFirstReveal,
    );
  }

  void onPresentationStarted() {
    _presenting = true;
  }

  void onPresentationFinished() {
    _presenting = false;
    state = null;
  }

  void onPresentationFailed() {
    _presenting = false;
    state = null;
  }
}

final collectorTypeCeremonyProvider =
    NotifierProvider<CollectorTypeCeremonyController, CollectorTypeCeremonyEvent?>(
  CollectorTypeCeremonyController.new,
);
