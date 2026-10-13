import 'dart:typed_data';

import 'package:flutter/painting.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/supabase_bootstrap.dart';
import '../../../core/network/content_revision.dart';
import '../../auth/presentation/auth_providers.dart';
import '../data/supabase_recipe_repository.dart';
import '../domain/recipe.dart';
import '../domain/recipe_repository.dart';

final recipeActorProvider = Provider<String?>(
  (ref) => ref.watch(
    authSessionProvider.select(
      (s) => s.isLoading || s.hasError ? null : s.value?.userId,
    ),
  ),
);
final recipeRepositoryProvider = Provider<RecipeRepository?>((ref) {
  final client = ref.watch(backendProvider).client;
  return client == null ? null : SupabaseRecipeRepository(client);
});
final recipeFilterProvider =
    NotifierProvider<RecipeFilterController, RecipeFilter>(
      RecipeFilterController.new,
    );

class RecipeFilterController extends Notifier<RecipeFilter> {
  @override
  RecipeFilter build() {
    ref.watch(recipeActorProvider);
    return const RecipeFilter();
  }

  void set(RecipeFilter value) => state = value;
}

final mineRecipesProvider =
    AsyncNotifierProvider.autoDispose<RecipesController, RecipePage>(
      RecipesController.new,
    );

class RecipesController extends AsyncNotifier<RecipePage> {
  int _generation = 0;
  @override
  Future<RecipePage> build() async {
    _generation++;
    final actor = ref.watch(recipeActorProvider);
    final filter = ref.watch(recipeFilterProvider);
    final repo = ref.watch(recipeRepositoryProvider);
    if (actor == null || repo == null) return const RecipePage([]);
    return repo.loadMine(filter);
  }

  Future<void> loadMore() async {
    final previous = state.value;
    if (previous == null || previous.cursor == null || previous.loadingMore) {
      return;
    }
    final generation = _generation;
    final actor = ref.read(recipeActorProvider);
    final repo = ref.read(recipeRepositoryProvider);
    if (repo == null || actor == null) return;
    final filter = ref.read(recipeFilterProvider);
    state = AsyncData(
      RecipePage(previous.recipes, cursor: previous.cursor, loadingMore: true),
    );
    try {
      final next = await repo.loadMine(filter, cursor: previous.cursor);
      if (!ref.mounted ||
          _generation != generation ||
          ref.read(recipeActorProvider) != actor) {
        return;
      }
      final ids = previous.recipes.map((r) => r.id).toSet();
      state = AsyncData(
        RecipePage(
          List.unmodifiable([
            ...previous.recipes,
            ...next.recipes.where((r) => ids.add(r.id)),
          ]),
          cursor: next.cursor,
        ),
      );
    } catch (error) {
      if (ref.mounted &&
          _generation == generation &&
          ref.read(recipeActorProvider) == actor) {
        state = AsyncData(
          RecipePage(
            previous.recipes,
            cursor: previous.cursor,
            moreFailure: error,
          ),
        );
      }
    }
  }
}

final recipeCategoriesProvider = FutureProvider.autoDispose<List<String>>((
  ref,
) async {
  if (ref.watch(recipeActorProvider) == null) return [];
  return await ref.watch(recipeRepositoryProvider)?.loadCategories() ?? [];
});
final ingredientCatalogProvider =
    FutureProvider.autoDispose<List<CatalogIngredient>>((ref) async {
      if (ref.watch(recipeActorProvider) == null) {
        throw const RecipeFailure(RecipeFailureCode.forbidden);
      }
      final repo = ref.watch(recipeRepositoryProvider);
      if (repo == null) throw const RecipeFailure(RecipeFailureCode.network);
      return repo.loadCatalog();
    });
final recipeDetailProvider = FutureProvider.autoDispose.family<Recipe?, String>(
  (ref, id) async {
    if (ref.watch(recipeActorProvider) == null) return null;
    return ref.watch(recipeRepositoryProvider)?.read(id);
  },
);
final recipePhotoProvider = FutureProvider.autoDispose
    .family<Uint8List, String>((ref, path) async {
      if (ref.watch(recipeActorProvider) == null) {
        throw const RecipeFailure(RecipeFailureCode.forbidden);
      }
      final repo = ref.watch(recipeRepositoryProvider);
      if (repo == null) throw const RecipeFailure(RecipeFailureCode.network);
      final bytes = await repo.downloadPhoto(path);
      if (ref.mounted) ref.onDispose(() => MemoryImage(bytes).evict());
      return bytes;
    });

enum RecipeActionStage {
  idle,
  saving,
  uploading,
  linking,
  changing,
  deleting,
  cancelling,
}

class RecipeActionState {
  const RecipeActionState({this.stage = RecipeActionStage.idle, this.failure});
  final RecipeActionStage stage;
  final RecipeFailureCode? failure;
  bool get busy => stage != RecipeActionStage.idle;
}

class RecipeSaveOutcome {
  const RecipeSaveOutcome({
    this.recipe,
    this.failure,
    this.photoPending = false,
  });
  final Recipe? recipe;
  final RecipeFailureCode? failure;
  final bool photoPending;
  bool get success => recipe != null && failure == null;
}

final recipeActionsProvider =
    NotifierProvider<RecipeActions, RecipeActionState>(RecipeActions.new);

class RecipeActions extends Notifier<RecipeActionState> {
  PhotoCancellation? _cancel;
  int _generation = 0;
  @override
  RecipeActionState build() {
    ref.watch(recipeActorProvider);
    _generation++;
    _cancel?.cancel();
    return const RecipeActionState();
  }

  bool _current(String actor, int generation) =>
      ref.mounted &&
      _generation == generation &&
      ref.read(recipeActorProvider) == actor;
  void _invalidate() {
    ref.read(contentRevisionProvider.notifier).changed();
    ref.invalidate(mineRecipesProvider);
    ref.invalidate(recipeCategoriesProvider);
    ref.invalidate(recipeDetailProvider);
    ref.invalidate(recipePhotoProvider);
  }

  void cancelPhoto() {
    _cancel?.cancel();
    if (state.busy) {
      state = const RecipeActionState(stage: RecipeActionStage.cancelling);
    }
  }

  void clearFailure() {
    if (!state.busy) state = const RecipeActionState();
  }

  Future<RecipeSaveOutcome> save(
    RecipeDraft draft, {
    Recipe? previous,
    required String requestId,
    Uint8List? photo,
    bool removePhoto = false,
  }) async {
    if (state.busy) return const RecipeSaveOutcome();
    final repo = ref.read(recipeRepositoryProvider);
    final actor = ref.read(recipeActorProvider);
    final generation = _generation;
    if (repo == null || actor == null) {
      return const RecipeSaveOutcome(failure: RecipeFailureCode.forbidden);
    }
    state = const RecipeActionState(stage: RecipeActionStage.saving);
    Recipe? saved;
    String? uploaded;
    final cancellation = PhotoCancellation();
    _cancel = cancellation;
    try {
      // Reconcile an unknown creation response before sending a changed draft.
      var baseline = previous;
      if (baseline == null) {
        final existing = await repo.lookupCreation(requestId);
        if (!_current(actor, generation)) return const RecipeSaveOutcome();
        if (existing != null) baseline = await repo.read(existing);
      }
      final id = await repo.save(
        draft,
        previous: baseline,
        requestId: requestId,
      );
      if (!_current(actor, generation)) return const RecipeSaveOutcome();
      saved = await repo.read(id);
      if (saved == null) throw const RecipeFailure(RecipeFailureCode.forbidden);
      if (!_current(actor, generation)) return const RecipeSaveOutcome();
      if (photo != null) {
        cancellation.check();
        state = const RecipeActionState(stage: RecipeActionStage.uploading);
        uploaded = await repo.uploadPhoto(saved, photo, cancellation);
        if (!_current(actor, generation)) return const RecipeSaveOutcome();
        cancellation.check();
        state = const RecipeActionState(stage: RecipeActionStage.linking);
        await repo.setPhoto(saved, uploaded);
        saved = await repo.read(id);
      } else if (removePhoto && saved.photoPath != null) {
        state = const RecipeActionState(stage: RecipeActionStage.linking);
        await repo.setPhoto(saved, null);
        saved = await repo.read(id);
      }
      if (!_current(actor, generation)) return const RecipeSaveOutcome();
      _invalidate();
      state = const RecipeActionState();
      return RecipeSaveOutcome(recipe: saved);
    } catch (error) {
      if (!_current(actor, generation)) return const RecipeSaveOutcome();
      final failure = error is RecipeFailure
          ? error.code
          : RecipeFailureCode.unexpected;
      // Do not remove an uploaded object on an ambiguous RPC response: it may
      // be the valid current photo. SQL queues every unlinked upload.
      if (saved != null) {
        try {
          final actual = await repo.read(saved.id);
          if (actual != null) saved = actual;
        } catch (_) {}
      }
      if (!_current(actor, generation)) return const RecipeSaveOutcome();
      if (failure == RecipeFailureCode.network &&
          uploaded != null &&
          saved?.photoPath == uploaded &&
          draft.matches(saved!)) {
        _invalidate();
        state = const RecipeActionState();
        return RecipeSaveOutcome(recipe: saved);
      }
      _invalidate();
      state = RecipeActionState(failure: failure);
      return RecipeSaveOutcome(
        recipe: saved,
        failure: failure,
        photoPending: saved != null && (photo != null || removePhoto),
      );
    } finally {
      if (_current(actor, generation)) _cancel = null;
    }
  }

  Future<bool> changeVisibility(Recipe recipe, RecipeVisibility visibility) =>
      _change(
        RecipeActionStage.changing,
        (repo) => repo.setVisibility(recipe, visibility),
      );
  Future<bool> delete(Recipe recipe) =>
      _change(RecipeActionStage.deleting, (repo) => repo.delete(recipe));
  Future<bool> _change(
    RecipeActionStage stage,
    Future<void> Function(RecipeRepository) operation,
  ) async {
    if (state.busy) return false;
    final repo = ref.read(recipeRepositoryProvider);
    final actor = ref.read(recipeActorProvider);
    final generation = _generation;
    if (repo == null || actor == null) return false;
    state = RecipeActionState(stage: stage);
    try {
      await operation(repo);
      if (!_current(actor, generation)) return false;
      _invalidate();
      state = const RecipeActionState();
      return true;
    } catch (error) {
      if (_current(actor, generation)) {
        state = RecipeActionState(
          failure: error is RecipeFailure
              ? error.code
              : RecipeFailureCode.unexpected,
        );
      }
      return false;
    }
  }
}
