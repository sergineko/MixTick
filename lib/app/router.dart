import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/widgets/app_states.dart';
import '../features/auth/presentation/access_page.dart';
import '../features/auth/presentation/access_status_page.dart';
import '../features/auth/presentation/auth_providers.dart';
import '../features/auth/presentation/session_page.dart';
import '../features/community/presentation/community_page.dart';
import '../features/cook_today/presentation/cook_today_page.dart';
import '../features/profile/presentation/profile_page.dart';
import '../features/recipes/presentation/recipes_page.dart';
import '../features/shopping/presentation/shopping_page.dart';
import '../shared/models/app_module.dart';
import 'app_shell.dart';
import 'localization/generated/app_localizations.dart';

final initialLocationProvider = Provider<String>(
  (ref) => AppModule.community.path,
);

class _SessionRefresh extends ChangeNotifier {
  void refresh() => notifyListeners();
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _SessionRefresh();
  ref.listen(authSessionProvider, (_, _) => refresh.refresh());
  final router = GoRouter(
    initialLocation: ref.read(initialLocationProvider),
    refreshListenable: refresh,
    redirect: (context, state) {
      final session = ref.read(authSessionProvider);
      final path = state.uri.path;
      final public = path == '/access' || path == '/access/status';
      if (session.isLoading) return path == '/session' ? null : '/session';
      if (session.hasError || session.value == null) {
        return public ? null : '/access';
      }
      return public || path == '/session' ? AppModule.community.path : null;
    },
    routes: [
      GoRoute(path: '/session', builder: (_, _) => const SessionPage()),
      GoRoute(path: '/access', builder: (_, _) => const AccessPage()),
      GoRoute(
        path: '/access/status',
        builder: (_, _) => const AccessStatusPage(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => AppShell(navigationShell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppModule.community.path,
                builder: (_, _) => const CommunityPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppModule.recipes.path,
                builder: (_, _) => const RecipesPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppModule.cookToday.path,
                builder: (_, _) => const CookTodayPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppModule.shopping.path,
                builder: (_, _) => const ShoppingPage(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(path: '/profile', builder: (_, _) => const ProfilePage()),
    ],
    errorBuilder: (context, state) {
      final strings = AppLocalizations.of(context);
      return Scaffold(
        body: SafeArea(
          child: AppErrorState(
            message: strings.routeNotFound,
            actionLabel: strings.goHome,
            onAction: () => context.go(AppModule.community.path),
          ),
        ),
      );
    },
  );
  ref.onDispose(router.dispose);
  ref.onDispose(refresh.dispose);
  return router;
});
