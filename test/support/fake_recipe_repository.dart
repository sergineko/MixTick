// Test double for UI/controller behavior only; never proves RLS or Storage.
import 'dart:async';
import 'dart:typed_data';

import 'package:mixtick/features/recipes/domain/recipe.dart';
import 'package:mixtick/features/recipes/domain/recipe_repository.dart';

const tomato = CatalogIngredient(
  id: '10000000-0000-4000-8000-000000000001',
  name: 'Tomate',
  aliases: ['Tomates'],
);
const egg = CatalogIngredient(
  id: '10000000-0000-4000-8000-000000000004',
  name: 'Huevo',
  aliases: ['Huevos'],
);
Recipe testRecipe({
  String id = '20000000-0000-4000-8000-000000000001',
  String author = 'test-a',
  String title = 'Tortilla de prueba',
  int version = 1,
  RecipeVisibility visibility = RecipeVisibility.private,
  String? photoPath,
  List<RecipeIngredient>? ingredients,
  List<String>? steps,
}) => Recipe(
  id: id,
  authorId: author,
  title: title,
  category: 'Principal',
  servings: 2,
  visibility: visibility,
  version: version,
  updatedAt: DateTime.utc(2026, 10, 13),
  photoPath: photoPath,
  ingredients:
      ingredients ??
      [
        RecipeIngredient(
          ingredientId: egg.id,
          name: egg.name,
          quantity: 2,
          unit: 'ud',
        ),
      ],
  steps: steps ?? ['Batir los huevos.', 'Cocinar.'],
);
RecipeDraft testDraft([String title = 'Tortilla de prueba']) => RecipeDraft(
  title: title,
  category: 'Principal',
  servings: 2,
  ingredients: [
    RecipeIngredient(
      ingredientId: egg.id,
      name: egg.name,
      quantity: 2,
      unit: 'ud',
    ),
  ],
  steps: ['Batir los huevos.', 'Cocinar.'],
);

class FakeRecipeRepository implements RecipeRepository {
  String actor = 'test-a';
  final recipes = <String, Recipe>{};
  final requests = <String, String>{};
  int saves = 0, creates = 0, uploads = 0, links = 0;
  bool loseCreationReply = false;
  RecipeFailure? failure, photoFailure, linkFailure;
  Completer<void>? pending, pendingPhoto;
  final filters = <RecipeFilter>[];
  @override
  Future<RecipePage> loadMine(
    RecipeFilter filter, {
    RecipeCursor? cursor,
  }) async {
    filters.add(filter);
    if (failure != null) throw failure!;
    final rows = recipes.values
        .where(
          (r) =>
              r.authorId == actor &&
              r.title.toLowerCase().contains(filter.search.toLowerCase()) &&
              (filter.category == null || filter.category == r.category) &&
              (filter.visibility == null || filter.visibility == r.visibility),
        )
        .toList();
    return RecipePage(rows);
  }

  @override
  Future<List<String>> loadCategories() async => recipes.values
      .where((r) => r.authorId == actor)
      .map((r) => r.category)
      .toSet()
      .toList();
  @override
  Future<List<CatalogIngredient>> loadCatalog() async => [tomato, egg];
  @override
  Future<CatalogIngredient?> resolveIngredient(String name) async =>
      [tomato, egg].where((i) => i.resolves(name)).firstOrNull;
  @override
  Future<Recipe?> read(String id) async => recipes[id];
  @override
  Future<String?> lookupCreation(String requestId) async => requests[requestId];
  @override
  Future<String> save(
    RecipeDraft draft, {
    Recipe? previous,
    required String requestId,
  }) async {
    saves++;
    await pending?.future;
    if (failure != null) throw failure!;
    if (previous != null && recipes[previous.id]?.version != previous.version) {
      throw const RecipeFailure(RecipeFailureCode.conflict);
    }
    final id =
        previous?.id ??
        requests[requestId] ??
        '20000000-0000-4000-8000-${(creates + 1).toString().padLeft(12, '0')}';
    if (previous == null && !requests.containsKey(requestId)) {
      creates++;
      requests[requestId] = id;
    }
    recipes[id] = Recipe(
      id: id,
      authorId: actor,
      title: draft.title,
      description: draft.description,
      category: draft.category,
      servings: draft.servings,
      prepMinutes: draft.prepMinutes,
      cookMinutes: draft.cookMinutes,
      visibility: previous?.visibility ?? RecipeVisibility.private,
      photoPath: previous?.photoPath,
      version: (previous?.version ?? 0) + 1,
      updatedAt: DateTime.now().toUtc(),
      ingredients: List.of(draft.ingredients),
      steps: List.of(draft.steps),
    );
    if (loseCreationReply) {
      loseCreationReply = false;
      throw const RecipeFailure(RecipeFailureCode.network);
    }
    return id;
  }

  @override
  Future<void> setVisibility(Recipe recipe, RecipeVisibility visibility) async {
    recipes[recipe.id] = testRecipe(
      id: recipe.id,
      author: recipe.authorId,
      title: recipe.title,
      version: recipe.version + 1,
      visibility: visibility,
      photoPath: recipe.photoPath,
      ingredients: recipe.ingredients,
      steps: recipe.steps,
    );
  }

  @override
  Future<void> delete(Recipe recipe) async {
    recipes.remove(recipe.id);
  }

  @override
  Future<String> uploadPhoto(
    Recipe recipe,
    Uint8List bytes,
    PhotoCancellation cancellation,
  ) async {
    uploads++;
    await pendingPhoto?.future;
    cancellation.check();
    if (photoFailure != null) throw photoFailure!;
    return 'test-a/${recipe.id}/photo.jpg';
  }

  @override
  Future<void> setPhoto(Recipe recipe, String? path) async {
    links++;
    if (linkFailure != null) throw linkFailure!;
    recipes[recipe.id] = testRecipe(
      id: recipe.id,
      author: recipe.authorId,
      title: recipe.title,
      version: recipe.version + 1,
      visibility: recipe.visibility,
      photoPath: path,
      ingredients: recipe.ingredients,
      steps: recipe.steps,
    );
  }

  @override
  Future<Uint8List> downloadPhoto(String path) async =>
      throw const RecipeFailure(RecipeFailureCode.photo);
}
