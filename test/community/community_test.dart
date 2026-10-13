import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mixtick/app/app.dart';
import 'package:mixtick/app/router.dart';
import 'package:mixtick/features/auth/domain/auth_session.dart';
import 'package:mixtick/features/auth/presentation/auth_providers.dart';
import 'package:mixtick/features/community/domain/community.dart';
import 'package:mixtick/features/community/presentation/community_providers.dart';

import 'package:mixtick/features/community/presentation/community_widgets.dart';
import 'package:mixtick/features/profile/presentation/profile_providers.dart';
import 'package:mixtick/features/profile/domain/user_profile.dart';
import 'package:mixtick/features/recipes/presentation/recipe_detail_page.dart';
import 'package:mixtick/features/recipes/presentation/recipe_providers.dart';
import 'package:mixtick/shared/models/app_module.dart';

import '../support/fake_community_repository.dart';
import '../support/fake_recipe_repository.dart';

Future<ProviderContainer> mountSocial(
  WidgetTester tester,
  FakeCommunityRepository repo, {
  String location = '/community',
  Stream<AuthSession?>? sessions,
}) async {
  final recipes = FakeRecipeRepository()..actor = 'test-b';
  recipes.recipes.addAll(
    repo.rows.map((id, entry) => MapEntry(id, entry.recipe)),
  );
  final container = ProviderContainer(
    overrides: [
      initialLocationProvider.overrideWithValue(location),
      authSessionProvider.overrideWith(
        (ref) => sessions ?? Stream.value(const AuthSession(userId: 'test-b')),
      ),
      communityRepositoryProvider.overrideWithValue(repo),
      recipeRepositoryProvider.overrideWithValue(recipes),
      publicProfileProvider.overrideWith((ref, name) async => communityAuthor),
      ownProfileProvider.overrideWith(
        (ref) async => const UserProfile(
          userId: 'test-b',
          version: 1,
          username: 'test_b',
          displayName: 'Prueba B',
        ),
      ),
    ],
  );
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    container.dispose();
  });
  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const MixTickApp()),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  if (sessions == null) await tester.pumpAndSettle();
  return container;
}

Future<void> tapSocial(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      finder,
      200,
      scrollable: find.byType(Scrollable).first,
    );
  }
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  WidgetController.hitTestWarningShouldBeFatal = true;
  test('C11 comment length counts Unicode characters, rejects whitespace and overlong input', () {
    expect(RecipeComment.valid(' \n\t '), false);
    expect(RecipeComment.valid('🍅' * 2000), true);
    expect(RecipeComment.valid('x' * 2001), false);
  });
  test(
    'C06 query identity separates saved, author, category and title caches',
    () {
      const original = CommunityQuery(search: 'tomate');
      expect(original, const CommunityQuery(search: 'tomate'));
      expect(
        original == const CommunityQuery(search: 'tomate', saved: true),
        false,
      );
      expect(
        original == const CommunityQuery(search: 'tomate', author: 'chef'),
        false,
      );
    },
  );
  testWidgets(
    'C07 card opens existing recipe detail without foreign owner controls (mock)',
    (tester) async {
      final repo = FakeCommunityRepository();
      final entry = socialFixture();
      repo.rows[entry.recipe.id] = entry;
      await mountSocial(tester, repo);
      await tapSocial(tester, find.byKey(ValueKey('open-${entry.recipe.id}')));
      expect(find.byType(RecipeDetailPage), findsOneWidget);
      expect(find.byKey(const ValueKey('edit-recipe')), findsNothing);
      expect(find.byKey(const ValueKey('delete-recipe')), findsNothing);
      expect(find.byType(SocialButtons), findsOneWidget);
    },
  );
  testWidgets(
    'C03 obsolete debounce cancels previous search, final term alone loads (mock)',
    (tester) async {
      final repo = FakeCommunityRepository();
      final entry = socialFixture();
      repo.rows[entry.recipe.id] = entry;
      await mountSocial(tester, repo);
      await tester.enterText(
        find.byKey(const ValueKey('community-search')),
        'Obsoleta',
      );
      await tester.pump(const Duration(milliseconds: 200));
      await tester.enterText(
        find.byKey(const ValueKey('community-search')),
        'Tortilla',
      );
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(repo.queries.last.search, 'Tortilla');
      expect(repo.queries.any((q) => q.search == 'Obsoleta'), false);
    },
  );
  testWidgets(
    'C27 saving in feed synchronizes recetario and original detail (mock)',
    (tester) async {
      final repo = FakeCommunityRepository();
      final entry = socialFixture();
      repo.rows[entry.recipe.id] = entry;
      await mountSocial(tester, repo);
      await tapSocial(tester, find.byKey(ValueKey('save-${entry.recipe.id}')));
      expect(repo.saved, {entry.recipe.id});
      await tapSocial(tester, find.byKey(const ValueKey(AppModule.recipes)));
      await tapSocial(tester, find.text('Guardadas'));
      expect(find.byType(CommunityRecipeCard), findsOneWidget);
      await tapSocial(tester, find.byKey(ValueKey('open-${entry.recipe.id}')));
      expect(find.text('Guardada'), findsOneWidget);
      await tapSocial(tester, find.byKey(ValueKey('save-${entry.recipe.id}')));
      expect(repo.saved, isEmpty);
      await tapSocial(tester, find.byType(BackButton));
      expect(find.byType(CommunityRecipeCard), findsNothing);
    },
  );
  testWidgets('C28 failed request hides rows and retry recovers (mock)', (
    tester,
  ) async {
    final repo = FakeCommunityRepository()
      ..failure = const CommunityFailure(CommunityFailureCode.network);
    repo.rows[socialFixture().recipe.id] = socialFixture();
    await mountSocial(tester, repo);
    expect(find.byType(CommunityRecipeCard), findsNothing);
    repo.failure = null;
    await tapSocial(tester, find.text('Reintentar').first);
    expect(find.byType(CommunityRecipeCard), findsOneWidget);
  });
  testWidgets(
    'C08 failed nonoptimistic write revalidates actual totals (mock)',
    (tester) async {
      final repo = FakeCommunityRepository();
      final entry = socialFixture();
      repo.rows[entry.recipe.id] = entry;
      await mountSocial(tester, repo);
      repo.failure = const CommunityFailure(CommunityFailureCode.network);
      await tapSocial(tester, find.byKey(ValueKey('like-${entry.recipe.id}')));
      expect(repo.liked, isEmpty);
      expect(find.byType(CommunityRecipeCard), findsNothing);
      repo.failure = null;
      await tapSocial(tester, find.text('Reintentar').first);
      expect(find.text('0 me gusta'), findsOneWidget);
    },
  );
  testWidgets(
    'C29 stale page response discarded after direct account change (mock)',
    (tester) async {
      final repo = FakeCommunityRepository(),
          sessions = StreamController<AuthSession?>();
      addTearDown(sessions.close);
      final entry = socialFixture();
      repo.rows[entry.recipe.id] = entry;
      repo.pendingPage = Completer<CommunityPageData>();
      await mountSocial(tester, repo, sessions: sessions.stream);
      sessions.add(const AuthSession(userId: 'test-a'));
      await tester.pump();
      final old = repo.pendingPage!;
      repo.pendingPage = null;
      repo.rows.clear();
      sessions.add(const AuthSession(userId: 'test-b'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      old.complete(CommunityPageData([entry]));
      await tester.pumpAndSettle();
      expect(find.byType(CommunityRecipeCard), findsNothing);
      expect(find.text(entry.recipe.title), findsNothing);
    },
  );
  testWidgets('C29 comment draft removed on logout and account switch (mock)', (
    tester,
  ) async {
    final repo = FakeCommunityRepository(),
        sessions = StreamController<AuthSession?>();
    addTearDown(sessions.close);
    final entry = socialFixture();
    repo.rows[entry.recipe.id] = entry;
    final container = await mountSocial(
      tester,
      repo,
      sessions: sessions.stream,
      location: '/recipes/${entry.recipe.id}/comments',
    );
    sessions.add(const AuthSession(userId: 'test-a'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('comment-input')),
      'Borrador de A',
    );
    sessions.add(const AuthSession(userId: 'test-b'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextFormField>(find.byKey(const ValueKey('comment-input')))
          .controller!
          .text,
      isEmpty,
    );
    sessions.add(null);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('comment-input')), findsNothing);
    expect(container.read(recipeActorProvider), isNull);
  });
  testWidgets('C24 report dialog closes when identity changes (mock)', (
    tester,
  ) async {
    final repo = FakeCommunityRepository(),
        sessions = StreamController<AuthSession?>();
    addTearDown(sessions.close);
    final entry = socialFixture();
    repo.rows[entry.recipe.id] = entry;
    await mountSocial(
      tester,
      repo,
      sessions: sessions.stream,
      location: '/recipes/${entry.recipe.id}',
    );
    sessions.add(const AuthSession(userId: 'test-b'));
    await tester.pumpAndSettle();
    await tapSocial(tester, find.text('Denunciar receta'));
    expect(find.byType(AlertDialog), findsOneWidget);
    sessions.add(const AuthSession(userId: 'test-c'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(repo.writes, 0);
  });
  testWidgets(
    'C06 pagination removes overlapping IDs and ignores obsolete generation (mock)',
    (tester) async {
      final repo = FakeCommunityRepository();
      for (var i = 1; i <= 3; i++) {
        final e = socialFixture(
          id: '20000000-0000-4000-8000-${i.toString().padLeft(12, '0')}',
        );
        repo.rows[e.recipe.id] = e;
      }
      final container = await mountSocial(tester, repo);
      final provider = communityPagesProvider(const CommunityQuery());
      await container.read(provider.notifier).loadMore();
      expect(container.read(provider).value!.entries.length, 3);
      expect(
        container
            .read(provider)
            .value!
            .entries
            .map((e) => e.recipe.id)
            .toSet()
            .length,
        3,
      );
      container.invalidate(provider);
      await tester.pumpAndSettle();
      repo.pendingPage = Completer<CommunityPageData>();
      final old = container.read(provider.notifier).loadMore();
      final late = repo.pendingPage!;
      repo.pendingPage = null;
      repo.rows.clear();
      container.invalidate(provider);
      await tester.pumpAndSettle();
      late.complete(CommunityPageData([socialFixture()]));
      await old;
      expect(container.read(provider).value!.entries, isEmpty);
    },
  );
  testWidgets(
    'C09 double action submission blocked while first request is pending (mock)',
    (tester) async {
      final repo = FakeCommunityRepository()..pendingWrite = Completer<void>();
      final entry = socialFixture();
      repo.rows[entry.recipe.id] = entry;
      final container = await mountSocial(tester, repo);
      final controller = container.read(socialActionsProvider.notifier);
      final first = controller.run((r) => r.like(entry.recipe.id, true));
      expect(await controller.run((r) => r.like(entry.recipe.id, true)), false);
      expect(repo.writes, 1);
      repo.pendingWrite!.complete();
      expect(await first, true);
    },
  );
  testWidgets(
    'C20 fresh permission gate hides a cached public aggregate after privatization (mock)',
    (tester) async {
      final repo = FakeCommunityRepository();
      final entry = socialFixture();
      repo.rows[entry.recipe.id] = entry;
      final container = await mountSocial(
        tester,
        repo,
        location: '/recipes/${entry.recipe.id}',
      );
      expect(find.byType(RecipeContent), findsOneWidget);
      repo.unavailable = true;
      container.invalidate(socialEntryProvider(entry.recipe.id));
      await tester.pumpAndSettle();
      expect(find.byType(RecipeContent), findsNothing);
      expect(find.text('Batir los huevos.'), findsNothing);
      expect(find.text(entry.recipe.title), findsNothing);
    },
  );
  for (final brightness in Brightness.values) {
    testWidgets(
      'C31 social cards and saved tabs at 200% on 320x640 $brightness (mock)',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        tester.platformDispatcher.platformBrightnessTestValue = brightness;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
        final repo = FakeCommunityRepository();
        final entry = socialFixture();
        repo.rows[entry.recipe.id] = entry;
        final container = await mountSocial(tester, repo);
        await tester.scrollUntilVisible(
          find.byKey(ValueKey('save-${entry.recipe.id}')),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        expect(tester.takeException(), isNull);
        await tapSocial(tester, find.byKey(const ValueKey(AppModule.recipes)));
        await tapSocial(tester, find.text('Guardadas'));
        expect(tester.takeException(), isNull);
        expect(find.byType(NavigationDestination), findsNWidgets(4));
        for (final module in [AppModule.cookToday, AppModule.shopping]) {
          container.read(routerProvider).go(module.path);
          await tester.pumpAndSettle();
          expect(find.byType(NavigationDestination), findsNWidgets(4));
        }
      },
    );
  }
}
