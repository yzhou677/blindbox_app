import 'package:blindbox_app/core/router/app_router.dart';
import 'package:blindbox_app/features/collection/insights/debug/companion/collector_companion.dart';
import 'package:blindbox_app/features/collection/insights/debug/companion/collector_companion_assets.dart';
import 'package:blindbox_app/features/collection/insights/debug/companion/collector_companion_playground.dart';
import 'package:blindbox_app/features/collection/insights/debug/companion/companion_reaction.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CollectorCompanion', () {
    testWidgets('starts idle and switches reactions', (tester) async {
      final key = GlobalKey<CollectorCompanionState>();
      CompanionReaction? completed;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CollectorCompanion(
              key: key,
              assets: CollectorCompanionAssets.completionist,
              size: 120,
              idleLife: false,
              onReactionCompleted: (r) => completed = r,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(key.currentState!.activeReaction, CompanionReaction.idle);

      key.currentState!.playReaction(CompanionReaction.happy);
      await tester.pump();
      expect(key.currentState!.activeReaction, CompanionReaction.happy);

      // Finish reaction timeline.
      await tester.pump(const Duration(seconds: 2));
      await tester.pump();
      expect(key.currentState!.activeReaction, CompanionReaction.idle);
      expect(completed, CompanionReaction.happy);
    });

    testWidgets('dispose cleans controllers without throw', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CollectorCompanion(
              assets: CollectorCompanionAssets.completionist,
              size: 80,
              idleLife: false,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });

    testWidgets('idle controllers keep ticking while looping', (tester) async {
      final key = GlobalKey<CollectorCompanionState>();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CollectorCompanion(
              key: key,
              assets: CollectorCompanionAssets.completionist,
              size: 80,
              idleLife: false,
              loopIdle: true,
            ),
          ),
        ),
      );
      await tester.pump();
      expect(key.currentState!.activeReaction, CompanionReaction.idle);
      await tester.pump(const Duration(milliseconds: 400));
      expect(key.currentState!.activeReaction, CompanionReaction.idle);
    });
  });

  group('CollectorCompanionPlayground', () {
    testWidgets('builds debug chrome and play controls', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        const MaterialApp(home: CollectorCompanionPlayground()),
      );
      await tester.pump();

      expect(find.textContaining('Companion Playground'), findsOneWidget);
      expect(find.byKey(const Key('companion_playground_play')), findsOneWidget);
      expect(find.byKey(const Key('companion_playground_reset')), findsOneWidget);
      expect(find.text('celebrate'), findsOneWidget);

      await tester.ensureVisible(find.text('celebrate'));
      await tester.tap(find.text('celebrate'));
      await tester.pump();
      await tester.tap(find.byKey(const Key('companion_playground_play')));
      await tester.pump();
      expect(find.textContaining('State: celebrate'), findsOneWidget);
    });
  });

  group('debug route', () {
    test('companion playground route path is debug-only constant', () {
      expect(kDebugMode, isTrue);
      expect(
        CollectorCompanionPlayground.routePath,
        '/debug/collector-companion',
      );
      // Route is registered on appRouter only when kDebugMode is true
      // (see app_router.dart). Release builds omit the GoRoute entirely.
      final flat = <GoRoute>[];
      void walk(List<RouteBase> routes) {
        for (final r in routes) {
          if (r is GoRoute) {
            flat.add(r);
            walk(r.routes);
          } else if (r is ShellRoute) {
            walk(r.routes);
          } else if (r is StatefulShellRoute) {
            for (final b in r.branches) {
              walk(b.routes);
            }
          }
        }
      }

      walk(appRouter.configuration.routes);
      expect(
        flat.any((r) => r.path == CollectorCompanionPlayground.routePath),
        isTrue,
      );
    });
  });
}
