import 'package:blindbox_app/core/router/app_router.dart';
import 'package:blindbox_app/features/collection/application/master_complete_celebration_controller.dart';
import 'package:blindbox_app/features/collection/widgets/master_complete_achievement_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Inserts global Master Complete overlays on the root navigator — above sheets.
class MasterCompleteCelebrationHost extends ConsumerStatefulWidget {
  const MasterCompleteCelebrationHost({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<MasterCompleteCelebrationHost> createState() =>
      _MasterCompleteCelebrationHostState();
}

class _MasterCompleteCelebrationHostState
    extends ConsumerState<MasterCompleteCelebrationHost> {
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

  void _present(MasterCompleteCelebrationEvent event, {int attempt = 0}) {
    if (_lastToken == event.token && _entry != null) return;
    _lastToken = event.token;

    _removeEntry();
    final overlay = rootNavigatorKey.currentState?.overlay;
    if (overlay == null) {
      _scheduleInsertRetry(event, attempt: attempt);
      return;
    }

    _entry = OverlayEntry(
      builder: (context) => MasterCompleteAchievementOverlay(
        key: ValueKey<int>(event.token),
        onFinished: () {
          _removeEntry();
          ref
              .read(masterCompleteCelebrationProvider.notifier)
              .onPresentationFinished();
        },
      ),
    );

    try {
      overlay.insert(_entry!);
    } catch (e, st) {
      debugPrint('Master Complete overlay insert failed: $e\n$st');
      _entry = null;
      _scheduleInsertRetry(event, attempt: attempt);
      return;
    }

    ref.read(masterCompleteCelebrationProvider.notifier).onPresentationStarted();
  }

  void _scheduleInsertRetry(
    MasterCompleteCelebrationEvent event, {
    required int attempt,
  }) {
    if (!mounted) return;
    if (attempt >= _maxInsertAttempts) {
      ref.read(masterCompleteCelebrationProvider.notifier).onPresentationFailed();
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _present(event, attempt: attempt + 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<MasterCompleteCelebrationEvent?>(
      masterCompleteCelebrationProvider,
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
