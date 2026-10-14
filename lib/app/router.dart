import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/widgets/app_states.dart';
import '../core/widgets/access_revalidation.dart';
import '../features/auth/presentation/access_page.dart';
import '../features/auth/presentation/access_status_page.dart';
import '../features/auth/presentation/auth_providers.dart';
import '../features/auth/presentation/session_page.dart';
import '../features/auth/presentation/auth_form_page.dart';
import '../features/auth/presentation/confirmation_page.dart';
import '../features/auth/presentation/session_scope.dart';
import '../features/auth/presentation/auth_link_error_page.dart';
import '../features/community/presentation/community_page.dart';
import '../features/community/presentation/comments_page.dart';
import '../features/community/presentation/blocked_authors_page.dart';
import '../features/cook_today/presentation/cook_today_page.dart';
import '../features/profile/presentation/profile_page.dart';
import '../features/profile/presentation/account_deletion_page.dart';
import '../features/profile/presentation/profile_edit_page.dart';
import '../features/profile/presentation/public_profile_page.dart';
import '../features/profile/presentation/profile_lookup_page.dart';
import '../features/recipes/presentation/recipes_page.dart';
import '../features/recipes/presentation/recipe_editor_page.dart';
import '../features/recipes/presentation/recipe_detail_page.dart';
import '../features/shopping/presentation/shopping_page.dart';
import '../features/shopping/presentation/shopping_detail_page.dart';
import '../features/shopping/presentation/shopping_import_page.dart';
import '../features/cook_today/domain/matching.dart';
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
  String? pendingLocation;
  bool isPublic(String path) =>
      path == '/access' ||
      path == '/access/status' ||
      {
        '/access/login',
        '/access/register',
        '/access/confirm',
        '/access/recovery',
        '/access/reset',
        '/access/link-error',
      }.contains(path);
  ref.listen(authSessionProvider, (_, _) => refresh.refresh());
  final router = GoRouter(
    observers: [ref.read(contentRouteObserverProvider)],
    initialLocation: ref.read(initialLocationProvider),
    refreshListenable: refresh,
    redirect: (context, state) {
      final session = ref.read(authSessionProvider);
      final path = state.uri.path;
      final public = path == '/access' || path == '/access/status';
      final publicAuth =
          public ||
          {
            '/access/login',
            '/access/register',
            '/access/confirm',
            '/access/recovery',
            '/access/reset',
            '/access/link-error',
          }.contains(path);
      if (session.isLoading) {
        if (path != '/session') pendingLocation = state.uri.toString();
        return path == '/session' ? null : '/session';
      }
      if (session.hasError || session.value == null) {
        if (path == '/session' && pendingLocation != null) {
          final destination = pendingLocation!;
          pendingLocation = null;
          return isPublic(Uri.parse(destination).path)
              ? destination
              : '/access';
        }
        return publicAuth ? null : '/access';
      }
      if (session.value!.requiresPasswordChange) {
        if (path == '/access/link-error') return null;
        return path == '/access/reset' ? null : '/access/reset';
      }
      if (path == '/access/link-error') return null;
      if (path == '/session' && pendingLocation != null) {
        final destination = pendingLocation!;
        pendingLocation = null;
        return isPublic(Uri.parse(destination).path)
            ? AppModule.community.path
            : destination;
      }
      return publicAuth || path == '/session' ? AppModule.community.path : null;
    },
    routes: [
      GoRoute(path: '/session', builder: (_, _) => const SessionPage()),
      GoRoute(path: '/access', builder: (_, _) => const AccessPage()),
      GoRoute(
        path: '/access/link-error',
        builder: (_, _) => const AuthLinkErrorPage(),
      ),
      GoRoute(
        path: '/access/login',
        builder: (_, _) =>
            const SessionScope(child: AuthFormPage(mode: AuthFormMode.signIn)),
      ),
      GoRoute(
        path: '/access/register',
        builder: (_, _) =>
            const SessionScope(child: AuthFormPage(mode: AuthFormMode.signUp)),
      ),
      GoRoute(
        path: '/access/recovery',
        builder: (_, _) => const SessionScope(
          child: AuthFormPage(mode: AuthFormMode.recovery),
        ),
      ),
      GoRoute(
        path: '/access/reset',
        builder: (_, _) => const SessionScope(
          child: AuthFormPage(mode: AuthFormMode.password),
        ),
      ),
      GoRoute(
        path: '/access/confirm',
        builder: (_, _) => const ConfirmationPage(),
      ),
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
      GoRoute(
        path: '/recipes/new',
        builder: (_, _) => const SessionScope(child: RecipeEditorPage()),
      ),
      GoRoute(
        path: '/recipes/:id/edit',
        builder: (_, state) => SessionScope(
          child: RecipeEditorPage(recipeId: state.pathParameters['id']!),
        ),
      ),
      GoRoute(
        path: '/community/blocked',
        builder: (_, _) => const SessionScope(child: BlockedAuthorsPage()),
      ),
      GoRoute(
        path: '/recipes/:id/comments',
        builder: (_, state) => SessionScope(
          child: CommentsPage(recipeId: state.pathParameters['id']!),
        ),
      ),
      GoRoute(
        path: '/recipes/:id',
        builder: (_, state) => SessionScope(
          child: RecipeDetailPage(
            id: state.pathParameters['id']!,
            missing: state.extra is MissingIngredientsTransfer
                ? state.extra as MissingIngredientsTransfer
                : null,
          ),
        ),
      ),
      GoRoute(
        path: '/shopping/list/:id',
        builder: (_, state) => SessionScope(
          child: ShoppingDetailPage(id: state.pathParameters['id']!),
        ),
      ),
      GoRoute(
        path: '/shopping/import/:id',
        builder: (_, state) => SessionScope(
          child: ShoppingImportPage(
            recipeId: state.pathParameters['id']!,
            missing: state.extra is MissingIngredientsTransfer
                ? state.extra as MissingIngredientsTransfer
                : null,
          ),
        ),
      ),
      GoRoute(path: '/profile', builder: (_, _) => const ProfilePage()),
      GoRoute(
        path: '/account/delete',
        builder: (_, _) => const SessionScope(child: AccountDeletionPage()),
      ),
      GoRoute(
        path: '/profile/find',
        builder: (_, _) => const SessionScope(child: ProfileLookupPage()),
      ),
      GoRoute(
        path: '/profile/edit',
        builder: (_, _) => const SessionScope(child: ProfileEditPage()),
      ),
      GoRoute(
        path: '/people/:username',
        builder: (_, state) =>
            PublicProfilePage(username: state.pathParameters['username']!),
      ),
      GoRoute(
        path: '/account/password',
        builder: (_, _) => const SessionScope(
          child: AuthFormPage(mode: AuthFormMode.password),
        ),
      ),
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
