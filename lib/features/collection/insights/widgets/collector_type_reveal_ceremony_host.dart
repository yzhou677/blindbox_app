import 'package:blindbox_app/core/router/app_router.dart';
import 'package:blindbox_app/features/collection/insights/application/collector_type_ceremony.dart';
import 'package:blindbox_app/features/collection/insights/widgets/collector_type_reveal_ceremony_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Presents Collector Type reveal ceremonies on the root navigator overlay.
///
/// Ceremony is an event; Insights hero card remains durable [Revealed] state.
class CollectorTypeRevealCeremonyHost extends ConsumerStatefulWidget {
  const CollectorTypeRevealCeremonyHost({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<CollectorTypeRevealCeremonyHost> createState() =>
      _CollectorTypeRevealCeremonyHostState();
}

class _CollectorTypeRevealCeremonyHostState
    extends ConsumerState<CollectorTypeRevealCeremonyHost> {
  static const _maxInsertAttempts = 30;

  OverlayEntry? _entry;
  int? _lastToken;

  @override
  void dispose() {
    _removeEntry();
    super.dispose();
  }

  void _removeEntry() {
    _entry?.remove();
    _entry = null;
  }

  void _present(CollectorTypeCeremonyEvent event, {int attempt = 0}) {
    if (_lastToken == event.token && _entry != null) return;
    _lastToken = event.token;

    _removeEntry();
    final overlay =
        rootNavigatorKey.currentState?.overlay ?? Overlay.maybeOf(context);
    if (overlay == null) {
      _scheduleInsertRetry(event, attempt: attempt);
      return;
    }

    _entry = OverlayEntry(
      builder: (context) => CollectorTypeRevealCeremonyOverlay(
        key: ValueKey<int>(event.token),
        identity: event.identity,
        isFirstReveal: event.isFirstReveal,
        onFinished: () {
          _removeEntry();
          ref
              .read(collectorTypeCeremonyProvider.notifier)
              .onPresentationFinished();
        },
      ),
    );

    try {
      overlay.insert(_entry!);
    } catch (e, st) {
      debugPrint('Collector Type ceremony overlay insert failed: $e\n$st');
      _entry = null;
      _scheduleInsertRetry(event, attempt: attempt);
      return;
    }

    ref.read(collectorTypeCeremonyProvider.notifier).onPresentationStarted();
  }

  void _scheduleInsertRetry(
    CollectorTypeCeremonyEvent event, {
    required int attempt,
  }) {
    if (!mounted) return;
    if (attempt >= _maxInsertAttempts) {
      ref.read(collectorTypeCeremonyProvider.notifier).onPresentationFailed();
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _present(event, attempt: attempt + 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<CollectorTypeCeremonyEvent?>(
      collectorTypeCeremonyProvider,
      (previous, next) {
        if (next == null) return;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _present(next);
        });
      },
    );
    return widget.child;
  }
}
