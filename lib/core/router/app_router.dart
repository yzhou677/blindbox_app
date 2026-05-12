import 'package:blindbox_app/features/collection/collection_screen.dart';
import 'package:blindbox_app/features/home/drop_detail_screen.dart';
import 'package:blindbox_app/features/home/home_screen.dart';
import 'package:blindbox_app/features/market/market_screen.dart';
import 'package:blindbox_app/shared/widgets/main_shell_scaffold.dart';
import 'package:flutter/material.dart';
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
              routes: [
                GoRoute(
                  path: 'detail/:id',
                  pageBuilder: (context, state) {
                    final id = state.pathParameters['id']!;
                    return CustomTransitionPage<void>(
                      key: state.pageKey,
                      child: DropDetailScreen(collectibleId: id),
                      transitionDuration: const Duration(milliseconds: 420),
                      transitionsBuilder: (context, animation, secondaryAnimation, child) {
                        final curved = CurvedAnimation(
                          parent: animation,
                          curve: Curves.easeOutCubic,
                          reverseCurve: Curves.easeInCubic,
                        );
                        return FadeTransition(
                          opacity: curved,
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0, 0.05),
                              end: Offset.zero,
                            ).animate(curved),
                            child: child,
                          ),
                        );
                      },
                    );
                  },
                ),
              ],
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
