import 'dart:typed_data';

import 'recipe.dart';

enum RecipeFailureCode {
  network,
  forbidden,
  invalid,
  conflict,
  quota,
  photo,
  cancelled,
  unexpected,
}

class RecipeFailure implements Exception {
  const RecipeFailure(this.code);
  final RecipeFailureCode code;
}

class PhotoCancellation {
  bool cancelled = false;
  void Function()? onCancel;
  void cancel() {
    cancelled = true;
    onCancel?.call();
  }

  void check() {
    if (cancelled) throw const RecipeFailure(RecipeFailureCode.cancelled);
  }
}

abstract interface class RecipeRepository {
  Future<RecipePage> loadMine(RecipeFilter filter, {RecipeCursor? cursor});
  Future<List<String>> loadCategories();
  Future<List<CatalogIngredient>> loadCatalog();
  Future<CatalogIngredient?> resolveIngredient(String name);
  Future<Recipe?> read(String id);
  Future<String?> lookupCreation(String requestId);
  Future<String> save(
    RecipeDraft draft, {
    Recipe? previous,
    required String requestId,
  });
  Future<void> setVisibility(Recipe recipe, RecipeVisibility visibility);
  Future<void> delete(Recipe recipe);
  Future<String> uploadPhoto(
    Recipe recipe,
    Uint8List bytes,
    PhotoCancellation cancellation,
  );
  Future<void> setPhoto(Recipe recipe, String? path);
  Future<Uint8List> downloadPhoto(String path);
}
