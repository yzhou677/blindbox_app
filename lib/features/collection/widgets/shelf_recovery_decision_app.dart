import 'package:blindbox_app/core/theme/app_theme.dart';
import 'package:blindbox_app/features/collection/application/shelf_recovery_import.dart';
import 'package:blindbox_app/features/collection/bootstrap/collection_app_bootstrap.dart';
import 'package:blindbox_app/features/collection/bootstrap/collection_recovery_gate.dart';
import 'package:blindbox_app/features/collection/data/shelf_recovery_pack.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/collection/widgets/shelf_recovery_dialog.dart';
import 'package:flutter/material.dart';

/// Cold-start shell: recovery dialog first, then [appBuilder] after a choice.
class ShelfRecoveryDecisionApp extends StatefulWidget {
  const ShelfRecoveryDecisionApp({
    super.key,
    required this.pack,
    required this.appBuilder,
    this.theme,
    this.darkTheme,
  });

  final ShelfRecoveryPackContents pack;

  /// Built after Import / Start fresh resolves (typically [BlindboxApp]).
  final WidgetBuilder appBuilder;

  /// Optional themes (tests pass a plain [ThemeData] to avoid font network I/O).
  final ThemeData? theme;
  final ThemeData? darkTheme;

  @override
  State<ShelfRecoveryDecisionApp> createState() =>
      _ShelfRecoveryDecisionAppState();
}

class _ShelfRecoveryDecisionAppState extends State<ShelfRecoveryDecisionApp> {
  final _navKey = GlobalKey<NavigatorState>();
  var _resolved = false;
  var _busy = false;
  String? _error;

  Future<void> _onImport() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final snapshot = await ShelfRecoveryImport.apply(widget.pack);
      CollectionAppBootstrap.prime(snapshot);
      CollectionRecoveryGate.clearPending();
      ShelfRecoveryPack.scheduleWrite(snapshot: snapshot);
      if (!mounted) return;
      setState(() {
        _resolved = true;
        _busy = false;
      });
    } catch (e, st) {
      debugPrint('Shelf recovery import failed: $e\n$st');
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = ShelfRecoveryDialogCopy.importFailed;
      });
    }
  }

  Future<void> _onStartFresh() async {
    if (_busy) return;
    final nav = _navKey.currentContext;
    if (nav == null) return;
    final confirmed = await showShelfRecoveryStartFreshConfirm(nav);
    if (!confirmed || !mounted) return;
    setState(() => _busy = true);
    try {
      await ShelfRecoveryPack.deletePack();
      // Empty shelf — same as no prefs / no pack cold start.
      CollectionAppBootstrap.prime(CollectionSnapshot.emptyTest());
      CollectionRecoveryGate.clearPending();
      if (!mounted) return;
      setState(() {
        _resolved = true;
        _busy = false;
      });
    } catch (e, st) {
      debugPrint('Shelf recovery start fresh failed: $e\n$st');
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = ShelfRecoveryDialogCopy.startFreshFailed;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_resolved) {
      return widget.appBuilder(context);
    }

    return MaterialApp(
      navigatorKey: _navKey,
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.system,
      theme: widget.theme ?? AppTheme.light(),
      darkTheme: widget.darkTheme ?? AppTheme.dark(),
      home: Scaffold(
        body: SafeArea(
          child: ShelfRecoveryDecisionPanel(
            summaryLine:
                ShelfRecoveryDialogCopy.summaryLineForPack(widget.pack),
            busy: _busy,
            errorMessage: _error,
            onImport: _onImport,
            onStartFresh: _onStartFresh,
          ),
        ),
      ),
    );
  }
}
