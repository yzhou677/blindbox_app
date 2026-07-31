import 'dart:async';

import 'package:blindbox_app/features/home/application/home_discover_refresh_controller.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Debounce window for flapping offline/online and resume+reconnect races.
const Duration kNetworkRecoveryDebounce = Duration(milliseconds: 800);

/// App-scoped offline → online / resume recovery coordinator.
///
/// Owns a single connectivity subscription. Discover pull-to-refresh triggers
/// IP revalidation separately via [HomeDiscoverRefreshNotifier].
class AppNetworkRecoveryNotifier extends Notifier<int> {
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  bool _online = true;
  bool _wasOffline = false;
  bool _recoveryScheduled = false;
  DateTime? _lastRecoveryAt;

  /// Injected streams/clocks for deterministic tests.
  @visibleForTesting
  static Stream<List<ConnectivityResult>> Function()? debugConnectivityStream;

  @visibleForTesting
  static Future<List<ConnectivityResult>> Function()? debugConnectivityCheck;

  @visibleForTesting
  static DateTime Function()? debugClock;

  DateTime get _now => (debugClock ?? DateTime.now)();

  @override
  int build() {
    ref.onDispose(() {
      _connectivitySub?.cancel();
      _connectivitySub = null;
    });

    _bindConnectivity();
    return 0;
  }

  void _bindConnectivity() {
    final streamFactory = debugConnectivityStream;
    final stream = streamFactory != null
        ? streamFactory()
        : Connectivity().onConnectivityChanged;

    _connectivitySub?.cancel();
    _connectivitySub = stream.listen(_onConnectivityEvent, onError: (_) {});

    final check = debugConnectivityCheck;
    if (check != null) {
      check().then(_onConnectivityEvent, onError: (_) {});
    } else {
      Connectivity().checkConnectivity().then(
        _onConnectivityEvent,
        onError: (_) {},
      );
    }
  }

  void _onConnectivityEvent(List<ConnectivityResult> results) {
    final online = _isOnline(results);
    final previouslyOnline = _online;
    _online = online;

    if (!online) {
      _wasOffline = true;
      return;
    }

    // React only to a meaningful offline → online transition.
    if (_wasOffline && online && !previouslyOnline) {
      _wasOffline = false;
      _scheduleRecovery();
      return;
    }

    if (_wasOffline && online) {
      // Offline flag set while results still reported online intermittently.
      _wasOffline = false;
      _scheduleRecovery();
    }
  }

  /// Called from [AppNetworkRecoveryHost] on foreground resume.
  void onAppResumed() {
    final check = debugConnectivityCheck;
    final future = check != null ? check() : Connectivity().checkConnectivity();
    future.then((results) {
      final online = _isOnline(results);
      final previouslyOnline = _online;
      _online = online;

      if (!online) {
        _wasOffline = true;
        return;
      }

      // Recover when we were offline (possibly while backgrounded), or when
      // link flipped to online across the resume boundary.
      if (_wasOffline || !previouslyOnline) {
        _wasOffline = false;
        _scheduleRecovery();
      }
    }, onError: (_) {});
  }

  void _scheduleRecovery() {
    if (_recoveryScheduled) return;
    final last = _lastRecoveryAt;
    if (last != null && _now.difference(last) < kNetworkRecoveryDebounce) {
      return;
    }

    _recoveryScheduled = true;
    Future<void>.delayed(kNetworkRecoveryDebounce, () {
      _recoveryScheduled = false;
      if (!_online) return;
      final lastAt = _lastRecoveryAt;
      if (lastAt != null &&
          _now.difference(lastAt) < kNetworkRecoveryDebounce) {
        return;
      }
      _lastRecoveryAt = _now;
      // Reuse Discover refresh: catalog + official feed + IP soft-revalidation.
      // Overlap guard inside the notifier prevents duplicate in-flight work.
      unawaited(ref.read(homeDiscoverRefreshProvider.notifier).refresh());
      final next = state + 1;
      state = next;
    });
  }

  static bool _isOnline(List<ConnectivityResult> results) =>
      results.any((r) => r != ConnectivityResult.none);

  /// Test helper — simulates a connectivity emission.
  @visibleForTesting
  void debugEmitConnectivity(List<ConnectivityResult> results) {
    _onConnectivityEvent(results);
  }
}

final appNetworkRecoveryProvider =
    NotifierProvider<AppNetworkRecoveryNotifier, int>(
      AppNetworkRecoveryNotifier.new,
    );

/// Host that owns the single app lifecycle observer for network recovery.
class AppNetworkRecoveryHost extends ConsumerStatefulWidget {
  const AppNetworkRecoveryHost({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AppNetworkRecoveryHost> createState() =>
      _AppNetworkRecoveryHostState();
}

class _AppNetworkRecoveryHostState extends ConsumerState<AppNetworkRecoveryHost>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(appNetworkRecoveryProvider);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(appNetworkRecoveryProvider.notifier).onAppResumed();
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
