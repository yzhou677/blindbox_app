import 'package:blindbox_app/core/theme/app_theme.dart';
import 'package:blindbox_app/features/collection/presentation/collection_modal_overlays.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pumps a host scaffold with an "Open" button that shows a single bottom
/// sheet and registers itself with the global overlay registry.
Future<BuildContext> _pumpHostWithSheet(WidgetTester tester) async {
  late BuildContext hostContext;
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: _HostScaffold(
        onContext: (ctx) => hostContext = ctx,
      ),
    ),
  );
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
  return hostContext;
}

void main() {
  // Always clear registry state between tests so isolated tests don't see
  // residual callbacks from a previous case.
  setUp(() {
    CollectionModalOverlayRegistry.instance.unregister();
    CollectionModalOverlayRegistry.instance.resetGuardForTest();
  });

  testWidgets('dismissCollectionModalOverlays closes open bottom sheet', (
    tester,
  ) async {
    final hostContext = await _pumpHostWithSheet(tester);
    expect(find.text('Add a series'), findsOneWidget);

    dismissCollectionModalOverlays(hostContext);
    await tester.pumpAndSettle();
    expect(find.text('Add a series'), findsNothing);
  });

  // ---------------------------------------------------------------------------
  // Lifecycle regression: navigation race that previously triggered
  // `StateError: Bad state: Future already completed`.
  // ---------------------------------------------------------------------------

  testWidgets(
    'CollectionModalOverlayRegistry.dismissAll is idempotent within a frame',
    (tester) async {
      await _pumpHostWithSheet(tester);
      expect(find.text('Add a series'), findsOneWidget);

      // Simulate the documented race: two near-simultaneous dismiss triggers
      // (e.g. MainShellScaffold direct dismiss + GoRouter listener dismiss).
      CollectionModalOverlayRegistry.instance.dismissAll();
      CollectionModalOverlayRegistry.instance.dismissAll();
      CollectionModalOverlayRegistry.instance.dismissAll();

      // Crucially, no exception should be thrown during the pop animation.
      await tester.pumpAndSettle();
      expect(find.text('Add a series'), findsNothing);
      expect(tester.takeException(), isNull);

      // The post-frame guard reset must allow a follow-up dismissAll later.
      CollectionModalOverlayRegistry.instance.dismissAll();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'repeated dismissCollectionModalOverlays during pop animation does not '
    'double-complete the route',
    (tester) async {
      final hostContext = await _pumpHostWithSheet(tester);
      expect(find.text('Add a series'), findsOneWidget);

      // Begin pop animation but do not let it settle.
      dismissCollectionModalOverlays(hostContext);
      await tester.pump(const Duration(milliseconds: 16));

      // Hit dismiss again while the animation is in flight.  Without the
      // userGestureInProgress / canPop guards this was the path that
      // double-completed the route's `_popCompleter`.
      dismissCollectionModalOverlays(hostContext);
      dismissCollectionModalOverlays(hostContext);

      await tester.pumpAndSettle();
      expect(find.text('Add a series'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'dismissAll is a no-op after unregister (e.g. screen disposed)',
    (tester) async {
      await _pumpHostWithSheet(tester);

      CollectionModalOverlayRegistry.instance.unregister();
      CollectionModalOverlayRegistry.instance.dismissAll();

      await tester.pumpAndSettle();
      // Sheet stays open — no registered callback means no pop.
      expect(find.text('Add a series'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'dismissCollectionModalOverlays is a no-op when nothing to pop',
    (tester) async {
      late BuildContext hostContext;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Builder(
            builder: (context) {
              hostContext = context;
              return const Scaffold(body: Center(child: Text('Empty')));
            },
          ),
        ),
      );

      dismissCollectionModalOverlays(hostContext);
      dismissCollectionModalOverlays(hostContext);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'rapid tab-switch simulation pops sheet exactly once',
    (tester) async {
      var dismissCallCount = 0;
      await _pumpHostWithSheet(tester);

      // Wrap the registered callback to count invocations.  In real code
      // CollectionScreen registers `_dismissBranchOverlays` once; here we
      // re-register a counting wrapper to observe how many times the guard
      // actually lets the pop through.
      final existing = _capturedCallback;
      expect(existing, isNotNull);
      CollectionModalOverlayRegistry.instance.register(() {
        dismissCallCount++;
        existing!();
      });

      // Three rapid dismissAll() invocations in the same animation frame.
      CollectionModalOverlayRegistry.instance.dismissAll();
      CollectionModalOverlayRegistry.instance.dismissAll();
      CollectionModalOverlayRegistry.instance.dismissAll();

      // Guard collapses these into a single invocation.
      expect(dismissCallCount, 1);

      await tester.pumpAndSettle();
      expect(find.text('Add a series'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}

VoidCallback? _capturedCallback;

class _HostScaffold extends StatefulWidget {
  const _HostScaffold({required this.onContext});

  final void Function(BuildContext) onContext;

  @override
  State<_HostScaffold> createState() => _HostScaffoldState();
}

class _HostScaffoldState extends State<_HostScaffold> {
  @override
  void initState() {
    super.initState();
    _capturedCallback = _dismiss;
    CollectionModalOverlayRegistry.instance.register(_dismiss);
  }

  @override
  void dispose() {
    CollectionModalOverlayRegistry.instance.unregister();
    super.dispose();
  }

  void _dismiss() {
    if (!mounted) return;
    dismissCollectionModalOverlays(context);
  }

  @override
  Widget build(BuildContext context) {
    widget.onContext(context);
    return Scaffold(
      body: Center(
        child: FilledButton(
          onPressed: () {
            showCollectionModalBottomSheet<void>(
              context: context,
              builder: (ctx, scroll) => ListView(
                controller: scroll,
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 120),
                  Center(child: Text('Add a series')),
                  SizedBox(height: 400),
                ],
              ),
            );
          },
          child: const Text('Open'),
        ),
      ),
    );
  }
}
