import 'package:blindbox_app/features/collection/collection_screen.dart';
import 'package:blindbox_app/features/home/home_screen.dart';
import 'package:blindbox_app/features/market/market_screen.dart';
import 'package:blindbox_app/shared/widgets/main_shell_scaffold.dart';
import 'package:go_router/go_router.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/home',
  routes: [
    GoRoute(
      path: '/',
      redirect: (context, state) => '/home',
    ),
    StatefulShellRoute.indexedStack(
      builder: (context, state, shell) => MainShellScaffold(shell: shell),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/home',
              pageBuilder: (context, state) => NoTransitionPage(
                key: state.pageKey,
                child: const HomeScreen(),
              ),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/market',
              pageBuilder: (context, state) => NoTransitionPage(
                key: state.pageKey,
                child: const MarketScreen(),
              ),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/collection',
              pageBuilder: (context, state) => NoTransitionPage(
                key: state.pageKey,
                child: const CollectionScreen(),
              ),
            ),
          ],
        ),
      ],
    ),
  ],
);
