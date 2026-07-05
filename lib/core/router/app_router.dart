import 'package:blindbox_app/features/catalog/presentation/catalog_browse_screen.dart';
import 'package:blindbox_app/features/collection/collection_screen.dart';
import 'package:blindbox_app/features/collection/insights/presentation/collection_insights_screen.dart';
import 'package:blindbox_app/features/home/drop_detail_screen.dart';
import 'package:blindbox_app/features/home/home_screen.dart';
import 'package:blindbox_app/features/market/market_detail_screen.dart';
import 'package:blindbox_app/features/market/market_screen.dart';
import 'package:blindbox_app/features/market/presentation/market_browse_search_screen.dart';
import 'package:blindbox_app/shared/widgets/main_shell_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Root navigator — used for app-wide achievement overlays above modal sheets.
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

final GoRouter appRouter = GoRouter(
  navigatorKey: rootNavigatorKey,
  initialLocation: '/collection',
  routes: [
    GoRoute(
      path: '/',
      redirect: (context, state) => '/collection',
    ),
    // Branch order matches bottom nav: Collection (0), Home/Discover (1), Market (2).
    StatefulShellRoute.indexedStack(
      builder: (context, state, shell) => MainShellScaffold(shell: shell),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/collection',
              pageBuilder: (context, state) => NoTransitionPage(
                key: state.pageKey,
                child: const CollectionScreen(),
              ),
              routes: [
                GoRoute(
                  path: 'insights',
                  pageBuilder: (context, state) => CustomTransitionPage<void>(
                    key: state.pageKey,
                    child: const CollectionInsightsScreen(),
                    transitionDuration: const Duration(milliseconds: 320),
                    transitionsBuilder:
                        (context, animation, secondaryAnimation, child) {
                      final curved = CurvedAnimation(
                        parent: animation,
                        curve: Curves.easeOutCubic,
                        reverseCurve: Curves.easeInCubic,
                      );
                      return FadeTransition(
                        opacity: curved,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0, 0.04),
                            end: Offset.zero,
                          ).animate(curved),
                          child: child,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
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
                  path: 'catalog',
                  pageBuilder: (context, state) => CustomTransitionPage<void>(
                    key: state.pageKey,
                    child: const CatalogBrowseScreen(),
                    transitionDuration: const Duration(milliseconds: 320),
                    transitionsBuilder:
                        (context, animation, secondaryAnimation, child) {
                      final curved = CurvedAnimation(
                        parent: animation,
                        curve: Curves.easeOutCubic,
                        reverseCurve: Curves.easeInCubic,
                      );
                      return FadeTransition(
                        opacity: curved,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0, 0.04),
                            end: Offset.zero,
                          ).animate(curved),
                          child: child,
                        ),
                      );
                    },
                  ),
                ),
                GoRoute(
                  path: 'detail/:id',
                  pageBuilder: (context, state) {
                    final id = state.pathParameters['id']!;
                    return CustomTransitionPage<void>(
                      key: state.pageKey,
                      child: DropDetailScreen(releaseId: id),
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
              routes: [
                GoRoute(
                  path: 'search',
                  pageBuilder: (context, state) => CustomTransitionPage<void>(
                    key: state.pageKey,
                    child: const MarketBrowseSearchScreen(),
                    transitionDuration: const Duration(milliseconds: 320),
                    transitionsBuilder:
                        (context, animation, secondaryAnimation, child) {
                      final curved = CurvedAnimation(
                        parent: animation,
                        curve: Curves.easeOutCubic,
                        reverseCurve: Curves.easeInCubic,
                      );
                      return FadeTransition(
                        opacity: curved,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0, 0.04),
                            end: Offset.zero,
                          ).animate(curved),
                          child: child,
                        ),
                      );
                    },
                  ),
                ),
                GoRoute(
                  path: 'listing/:id',
                  pageBuilder: (context, state) {
                    final id = state.pathParameters['id']!;
                    return CustomTransitionPage<void>(
                      key: state.pageKey,
                      child: MarketDetailScreen(listingId: id),
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
      ],
    ),
  ],
);
