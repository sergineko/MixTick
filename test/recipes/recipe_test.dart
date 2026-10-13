import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mixtick/app/app.dart';
import 'package:mixtick/app/router.dart';
import 'package:mixtick/features/auth/domain/auth_session.dart';
import 'package:mixtick/features/auth/presentation/auth_providers.dart';
import 'package:mixtick/features/profile/domain/user_profile.dart';
import 'package:mixtick/features/profile/presentation/profile_providers.dart';
import 'package:mixtick/features/recipes/domain/recipe.dart';
import 'package:mixtick/features/recipes/domain/recipe_repository.dart';
import 'package:mixtick/features/recipes/presentation/recipe_providers.dart';

import '../support/fake_recipe_repository.dart';

Future<ProviderContainer> mountRecipe(
  WidgetTester tester,
  FakeRecipeRepository repo, {
  String location = '/recipes/new',
  Stream<AuthSession?>? sessions,
}) async {
  final container = ProviderContainer(
    overrides: [
      initialLocationProvider.overrideWithValue(location),
      authSessionProvider.overrideWith(
        (ref) => sessions ?? Stream.value(const AuthSession(userId: 'test-a')),
      ),
      ownProfileProvider.overrideWith(
        (ref) async => const UserProfile(
          userId: 'test-a',
          username: 'test_a',
          displayName: 'Prueba',
          version: 1,
        ),
      ),
      recipeRepositoryProvider.overrideWithValue(repo),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const MixTickApp()),
  );
  if (sessions == null) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump(const Duration(milliseconds: 400));
  }
  return container;
}

Future<void> tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> fillRecipe(WidgetTester tester) async {
  await tester.enterText(
    find.byKey(const ValueKey('recipe-title')),
    'Sopa de tomates',
  );
  await tester.enterText(
    find.byKey(const ValueKey('recipe-category')),
    'Entrante',
  );
  await tap(tester, find.byKey(const ValueKey('add-recipe-ingredient')));
  await tester.enterText(
    find.byKey(const ValueKey('ingredient-name')),
    'Tomates',
  );
  await tester.enterText(
    find.byKey(const ValueKey('ingredient-quantity')),
    '1,250',
  );
  await tester.enterText(find.byKey(const ValueKey('ingredient-unit')), 'kg');
  await tap(tester, find.byKey(const ValueKey('confirm-ingredient')));
  await tester.enterText(
    find.byKey(const ValueKey('recipe-step-0')),
    'Cocer los tomates.',
  );
}

void main() {
  WidgetController.hitTestWarningShouldBeFatal = true;
  test('R03 amounts, precision, comma and SQL bounds', () {
    expect(RecipeValidation.parseDecimal('1,250'), 1.25);
    for (final n in [
      0.0,
      -1.0,
      double.nan,
      double.infinity,
      1000000.001,
      1.0001,
    ]) {
      expect(RecipeValidation.decimal(n, 1000000, 3), false);
    }
    expect(RecipeValidation.decimal(0.001, 1000000, 3), true);
    expect(RecipeValidation.decimal(2.123, 10000, 2), false);
  });
  test('R02 canonical aliases without heuristic singularization', () {
    expect(tomato.resolves(' tOMÁTES '), true);
    expect(egg.matches('huev'), true);
    expect(tomato.resolves('tomat'), false);
    expect(normalizeIngredientText('Pimentón  PICANTE'), 'pimenton picante');
  });
  test('R07 R17 required aggregate, optional ingredient and duplicates', () {
    expect(testDraft().valid, true);
    final item = RecipeIngredient(
      ingredientId: egg.id,
      name: egg.name,
      optional: true,
    );
    expect(
      RecipeDraft(
        title: 'Prueba',
        category: 'Principal',
        servings: 1,
        ingredients: [item, item],
        steps: ['Cocer'],
      ).valid,
      false,
    );
    expect(
      RecipeDraft(
        title: 'Prueba',
        category: 'Principal',
        servings: 1,
        ingredients: [item],
        steps: [],
      ).valid,
      false,
    );
    expect(
      RecipeDraft(
        title: 'Prueba',
        category: 'Principal',
        servings: 1,
        ingredients: [item],
        steps: ['Cocer'],
      ).valid,
      true,
    );
  });
  test('R06 DTO sorts server ordinals and preserves typed quantities', () {
    final recipe = Recipe.fromJson({
      'id': 'id',
      'author_id': 'a',
      'title': 't',
      'category': 'c',
      'servings': 2.5,
      'visibility': 'private',
      'version': 2,
      'updated_at': '2026-10-13T00:00:00Z',
      'recipe_ingredients': [
        {
          'ingredient_id': egg.id,
          'custom_name': null,
          'ingredients': {'canonical_name_es': 'Huevo'},
          'quantity': 2.125,
          'unit': 'ud',
          'optional': true,
          'sort_order': 0,
        },
      ],
      'recipe_steps': [
        {'instruction': 'Segundo', 'sort_order': 1},
        {'instruction': 'Primero', 'sort_order': 0},
      ],
    });
    expect(recipe.steps, ['Primero', 'Segundo']);
    expect(recipe.ingredients.single.quantity, 2.125);
    expect(recipe.ingredients.single.optional, true);
  });
  testWidgets('R01 R02 R03 editor saves canonical recipe privately (UI mock)', (
    tester,
  ) async {
    final repo = FakeRecipeRepository();
    await mountRecipe(tester, repo);
    await fillRecipe(tester);
    await tap(tester, find.byKey(const ValueKey('save-recipe')));
    expect(repo.creates, 1);
    final recipe = repo.recipes.values.single;
    expect(recipe.visibility, RecipeVisibility.private);
    expect(recipe.ingredients.single.ingredientId, tomato.id);
    expect(recipe.ingredients.single.quantity, 1.25);
    expect(recipe.ingredients.single.unit, 'kg');
    expect(find.text('Sopa de tomates'), findsOneWidget);
  });
  testWidgets('R16 draft survives recoverable network failure (UI mock)', (
    tester,
  ) async {
    final repo = FakeRecipeRepository()
      ..failure = const RecipeFailure(RecipeFailureCode.network);
    await mountRecipe(tester, repo);
    await fillRecipe(tester);
    await tap(tester, find.byKey(const ValueKey('save-recipe')));
    expect(find.textContaining('tus cambios siguen'), findsOneWidget);
    expect(
      tester
          .widget<TextFormField>(find.byKey(const ValueKey('recipe-title')))
          .controller!
          .text,
      'Sopa de tomates',
    );
    repo.failure = null;
    await tap(tester, find.byKey(const ValueKey('save-recipe')));
    expect(repo.creates, 1);
  });
  testWidgets('R06 editor reorders and removes steps (UI mock)', (
    tester,
  ) async {
    final repo = FakeRecipeRepository();
    final recipe = testRecipe();
    repo.recipes[recipe.id] = recipe;
    await mountRecipe(tester, repo, location: '/recipes/${recipe.id}/edit');
    await tap(tester, find.byTooltip('Subir paso').last);
    expect(
      tester
          .widget<TextFormField>(find.byKey(const ValueKey('recipe-step-0')))
          .controller!
          .text,
      'Cocinar.',
    );
    await tap(tester, find.byKey(const ValueKey('save-recipe')));
    expect(repo.recipes[recipe.id]!.steps, ['Cocinar.', 'Batir los huevos.']);
  });
  testWidgets('R18 conflict retains local title and offers reload (UI mock)', (
    tester,
  ) async {
    final repo = FakeRecipeRepository();
    final recipe = testRecipe();
    repo.recipes[recipe.id] = recipe;
    await mountRecipe(tester, repo, location: '/recipes/${recipe.id}/edit');
    await tester.enterText(
      find.byKey(const ValueKey('recipe-title')),
      'Mis cambios',
    );
    repo.recipes[recipe.id] = testRecipe(version: 2);
    await tap(tester, find.byKey(const ValueKey('save-recipe')));
    expect(find.textContaining('otra sesión'), findsOneWidget);
    expect(
      tester
          .widget<TextFormField>(find.byKey(const ValueKey('recipe-title')))
          .controller!
          .text,
      'Mis cambios',
    );
    expect(
      tester
          .widget<FilledButton>(find.byKey(const ValueKey('save-recipe')))
          .onPressed,
      isNull,
    );
    await tap(tester, find.text('Recargar receta'));
    await tap(tester, find.widgetWithText(FilledButton, 'Recargar receta'));
    expect(
      tester
          .widget<TextFormField>(find.byKey(const ValueKey('recipe-title')))
          .controller!
          .text,
      'Tortilla de prueba',
    );
    expect(tester.takeException(), isNull);
  });
  testWidgets('R19 change of authenticated account discards form (UI mock)', (
    tester,
  ) async {
    final changes = StreamController<AuthSession?>();
    addTearDown(changes.close);
    final repo = FakeRecipeRepository();
    final container = await mountRecipe(tester, repo, sessions: changes.stream);
    changes.add(const AuthSession(userId: 'test-a'));
    await tester.pumpAndSettle();
    container.read(routerProvider).go('/recipes/new');
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('recipe-title')),
      'Secreto A',
    );
    changes.add(const AuthSession(userId: 'test-b'));
    repo.actor = 'test-b';
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextFormField>(find.byKey(const ValueKey('recipe-title')))
          .controller!
          .text,
      isEmpty,
    );
  });
  testWidgets(
    'R19 open ingredient modal closes on direct account change (UI mock)',
    (tester) async {
      final changes = StreamController<AuthSession?>();
      addTearDown(changes.close);
      final repo = FakeRecipeRepository();
      final container = await mountRecipe(
        tester,
        repo,
        sessions: changes.stream,
      );
      changes.add(const AuthSession(userId: 'test-a'));
      await tester.pumpAndSettle();
      container.read(routerProvider).go('/recipes/new');
      await tester.pumpAndSettle();
      await tap(tester, find.byKey(const ValueKey('add-recipe-ingredient')));
      await tester.enterText(
        find.byKey(const ValueKey('ingredient-name')),
        'Ingrediente privado A',
      );
      changes.add(const AuthSession(userId: 'test-b'));
      repo.actor = 'test-b';
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('ingredient-name')), findsNothing);
      expect(find.text('Ingrediente privado A'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'R12 filtering and saved section contains no fake saved recipes',
    (tester) async {
      final repo = FakeRecipeRepository();
      final recipe = testRecipe();
      repo.recipes[recipe.id] = recipe;
      await mountRecipe(tester, repo, location: '/recipes');
      await tester.enterText(
        find.byKey(const ValueKey('recipe-search')),
        'Tortilla',
      );
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(repo.filters.last.search, 'Tortilla');
      await tester.scrollUntilVisible(
        find.text('Tortilla de prueba'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Tortilla de prueba'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Recetas públicas guardadas'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Recetas públicas guardadas'), findsOneWidget);
      expect(find.byKey(const ValueKey('open-saved-recipes')), findsOneWidget);
      await tap(tester, find.byKey(const ValueKey('open-saved-recipes')));
      // Saved is now real; an unconfigured community backend never supplies
      // fake references from the own-recipe fixture repository.
      expect(find.text('Tortilla de prueba'), findsNothing);
      expect(find.textContaining('Configura'), findsWidgets);
      expect(find.byType(NavigationDestination), findsNWidgets(4));
    },
  );
  testWidgets('R10 reusable public detail hides owner mutations (UI mock)', (
    tester,
  ) async {
    final repo = FakeRecipeRepository();
    final recipe = testRecipe(
      author: 'test-b',
      visibility: RecipeVisibility.public,
    );
    repo.recipes[recipe.id] = recipe;
    await mountRecipe(tester, repo, location: '/recipes/${recipe.id}');
    expect(find.byKey(const ValueKey('edit-recipe')), findsNothing);
    expect(find.byKey(const ValueKey('delete-recipe')), findsNothing);
    expect(find.text('Batir los huevos.'), findsOneWidget);
  });
  for (final brightness in Brightness.values) {
    testWidgets('Recipe editor 320x640 at 200% $brightness', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      tester.platformDispatcher.platformBrightnessTestValue = brightness;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      await mountRecipe(tester, FakeRecipeRepository());
      expect(tester.takeException(), isNull);
      await tap(tester, find.byKey(const ValueKey('add-recipe-ingredient')));
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets(
    'R17 retry lost creation response edits one recipe (controller mock)',
    (tester) async {
      final repo = FakeRecipeRepository()..loseCreationReply = true;
      final container = await mountRecipe(tester, repo);
      final actions = container.read(recipeActionsProvider.notifier);
      final request = newRecipeRequestId();
      expect(
        (await actions.save(testDraft(), requestId: request)).failure,
        RecipeFailureCode.network,
      );
      expect(
        (await actions.save(
          testDraft('Updated draft'),
          requestId: request,
        )).success,
        true,
      );
      expect(repo.creates, 1);
      expect(repo.recipes.values.single.title, 'Updated draft');
    },
  );
  testWidgets(
    'Double submission blocked until operation finishes (controller mock)',
    (tester) async {
      final repo = FakeRecipeRepository()..pending = Completer<void>();
      final container = await mountRecipe(tester, repo);
      final actions = container.read(recipeActionsProvider.notifier);
      final first = actions.save(testDraft(), requestId: newRecipeRequestId());
      await tester.pump();
      final second = await actions.save(
        testDraft(),
        requestId: newRecipeRequestId(),
      );
      expect(second.success, false);
      expect(repo.saves, 1);
      repo.pending!.complete();
      expect((await first).success, true);
    },
  );
  testWidgets(
    'R15 photo failure preserves text and original reference (controller mock)',
    (tester) async {
      final repo = FakeRecipeRepository()
        ..photoFailure = const RecipeFailure(RecipeFailureCode.photo);
      final previous = testRecipe(photoPath: 'test-a/old/photo.jpg');
      repo.recipes[previous.id] = previous;
      final container = await mountRecipe(tester, repo);
      final result = await container
          .read(recipeActionsProvider.notifier)
          .save(
            testDraft('New text'),
            previous: previous,
            requestId: newRecipeRequestId(),
            photo: Uint8List(1),
          );
      expect(result.photoPending, true);
      expect(result.recipe!.title, 'New text');
      expect(result.recipe!.photoPath, previous.photoPath);
      expect(repo.links, 0);
    },
  );
  testWidgets(
    'R15 cancellation waits upload and never links it (controller mock)',
    (tester) async {
      final repo = FakeRecipeRepository()..pendingPhoto = Completer<void>();
      final container = await mountRecipe(tester, repo);
      final actions = container.read(recipeActionsProvider.notifier);
      final save = actions.save(
        testDraft(),
        requestId: newRecipeRequestId(),
        photo: Uint8List(1),
      );
      await tester.pump();
      await tester.pump();
      actions.cancelPhoto();
      repo.pendingPhoto!.complete();
      final result = await save;
      expect(result.failure, RecipeFailureCode.cancelled);
      expect(repo.links, 0);
      expect(repo.recipes.length, 1);
    },
  );
}
