import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../profile/data/avatar_processor.dart';
import '../../profile/domain/user_profile.dart';
import '../domain/recipe.dart';
import '../domain/recipe_repository.dart';

class SupabaseRecipeRepository implements RecipeRepository {
  const SupabaseRecipeRepository(this.client);
  final SupabaseClient client;
  static const bucket = 'recipe-photos';
  static const columns =
      'id,author_id,title,description,category,servings,prep_minutes,cook_minutes,visibility,hero_image_path,version,updated_at';
  static const detailColumns =
      '$columns,recipe_ingredients(ingredient_id,custom_name,quantity,unit,optional,sort_order,ingredients(canonical_name_es)),recipe_steps(sort_order,instruction)';
  static const pageSize = 8;
  String get actor =>
      client.auth.currentUser?.id ??
      (throw const RecipeFailure(RecipeFailureCode.forbidden));
  void _sameActor(String uid) {
    if (actor != uid) throw const RecipeFailure(RecipeFailureCode.forbidden);
  }

  Future<T> _run<T>(Future<T> Function() operation) async {
    try {
      final uid = actor;
      final result = await operation();
      _sameActor(uid);
      return result;
    } on RecipeFailure {
      rethrow;
    } on SocketException {
      throw const RecipeFailure(RecipeFailureCode.network);
    } on http.ClientException {
      throw const RecipeFailure(RecipeFailureCode.network);
    } on TimeoutException {
      throw const RecipeFailure(RecipeFailureCode.network);
    } on ProfileFailure {
      throw const RecipeFailure(RecipeFailureCode.photo);
    } on PostgrestException catch (e) {
      throw RecipeFailure(switch (e.code) {
        'PT409' || '23505' => RecipeFailureCode.conflict,
        '42501' || 'PGRST301' || 'PGRST303' => RecipeFailureCode.forbidden,
        'PT429' => RecipeFailureCode.quota,
        '22023' || '23514' || '22P02' || '22003' => RecipeFailureCode.invalid,
        _ => RecipeFailureCode.unexpected,
      });
    } on StorageException {
      throw const RecipeFailure(RecipeFailureCode.photo);
    } catch (_) {
      throw const RecipeFailure(RecipeFailureCode.unexpected);
    }
  }

  @override
  Future<RecipePage> loadMine(
    RecipeFilter filter, {
    RecipeCursor? cursor,
  }) => _run(() async {
    var query = client.from('recipes').select(columns).eq('author_id', actor);
    if (filter.search.trim().isNotEmpty) {
      final escaped = filter.search
          .trim()
          .replaceAll(r'\', r'\\')
          .replaceAll('%', r'\%')
          .replaceAll('_', r'\_');
      query = query.ilike('title', '%$escaped%');
    }
    if (filter.category != null) query = query.eq('category', filter.category!);
    if (filter.visibility != null) {
      query = query.eq('visibility', filter.visibility!.name);
    }
    if (cursor != null) {
      if (!RegExp(r'^[0-9a-f-]{36}$').hasMatch(cursor.id)) {
        throw const RecipeFailure(RecipeFailureCode.invalid);
      }
      final stamp = cursor.updatedAt.toUtc().toIso8601String();
      query = query.or(
        'updated_at.lt.$stamp,and(updated_at.eq.$stamp,id.lt.${cursor.id})',
      );
    }
    final rows = await query
        .order('updated_at', ascending: false)
        .order('id', ascending: false)
        .limit(pageSize + 1);
    final recipes = rows.take(pageSize).map(Recipe.fromJson).toList();
    return RecipePage(
      List.unmodifiable(recipes),
      cursor: rows.length > pageSize
          ? RecipeCursor(recipes.last.updatedAt, recipes.last.id)
          : null,
    );
  });
  @override
  Future<List<String>> loadCategories() => _run(() async {
    final found = <String>{};
    for (var offset = 0; ; offset += 500) {
      final rows = await client
          .from('recipes')
          .select('category')
          .eq('author_id', actor)
          .order('id')
          .range(offset, offset + 499);
      found.addAll(rows.map((r) => r['category'] as String));
      if (rows.length < 500) break;
    }
    return found.toList()..sort();
  });
  @override
  Future<List<CatalogIngredient>> loadCatalog() => _run(() async {
    final result = <CatalogIngredient>[];
    for (var offset = 0; ; offset += 200) {
      final rows = await client
          .from('ingredients')
          .select('id,canonical_name_es,ingredient_aliases(alias_es)')
          .eq('approved', true)
          .order('id')
          .range(offset, offset + 199);
      result.addAll(
        rows.map(
          (r) => CatalogIngredient(
            id: r['id'] as String,
            name: r['canonical_name_es'] as String,
            aliases: (r['ingredient_aliases'] as List)
                .map((a) => (a as Map)['alias_es'] as String)
                .toList(),
          ),
        ),
      );
      if (rows.length < 200) break;
    }
    return result..sort((a, b) => a.name.compareTo(b.name));
  });
  @override
  Future<Recipe?> read(String id) => _run(() async {
    final row = await client
        .from('recipes')
        .select(detailColumns)
        .eq('id', id)
        .maybeSingle();
    return row == null ? null : Recipe.fromJson(row);
  });
  @override
  Future<CatalogIngredient?> resolveIngredient(String name) => _run(() async {
    if (name.trim().isEmpty || name.trim().runes.length > 80) {
      throw const RecipeFailure(RecipeFailureCode.invalid);
    }
    final id = await client.rpc('resolve_ingredient', params: {'p_name': name});
    if (id == null) return null;
    final row = await client
        .from('ingredients')
        .select('id,canonical_name_es')
        .eq('id', id as String)
        .single();
    return CatalogIngredient(
      id: row['id'] as String,
      name: row['canonical_name_es'] as String,
    );
  });
  @override
  Future<String?> lookupCreation(String requestId) => _run(
    () async => await client.rpc(
      'lookup_recipe_creation',
      params: {'p_request_id': requestId},
    ) as String?,
  );
  @override
  Future<String> save(
    RecipeDraft draft, {
    Recipe? previous,
    required String requestId,
  }) => _run(() async {
    if (!draft.valid) throw const RecipeFailure(RecipeFailureCode.invalid);
    if (previous != null && previous.authorId != actor) {
      throw const RecipeFailure(RecipeFailureCode.forbidden);
    }
    final params = <String, dynamic>{
      'p_recipe': draft.header,
      'p_ingredients': draft.ingredients.map((i) => i.toJson()).toList(),
      'p_steps': draft.steps.map((s) => s.trim()).toList(),
    };
    if (previous == null) {
      params['p_request_id'] = requestId;
      return await client.rpc('create_recipe_once', params: params) as String;
    }
    params.addAll({
      'p_recipe_id': previous.id,
      'p_expected_version': previous.version,
    });
    return await client.rpc('save_recipe', params: params) as String;
  });
  @override
  Future<void> setVisibility(Recipe recipe, RecipeVisibility visibility) =>
      _run(() async {
        if (recipe.authorId != actor) {
          throw const RecipeFailure(RecipeFailureCode.forbidden);
        }
        await client.rpc(
          'set_recipe_visibility',
          params: {
            'p_recipe_id': recipe.id,
            'p_expected_version': recipe.version,
            'p_visibility': visibility.name,
          },
        );
      });
  @override
  Future<void> delete(Recipe recipe) => _run(() async {
    if (recipe.authorId != actor) {
      throw const RecipeFailure(RecipeFailureCode.forbidden);
    }
    await client.rpc(
      'delete_recipe_versioned',
      params: {'p_recipe_id': recipe.id, 'p_expected_version': recipe.version},
    );
  });
  @override
  Future<String> uploadPhoto(
    Recipe recipe,
    Uint8List bytes,
    PhotoCancellation cancellation,
  ) => _run(() async {
    final uid = actor;
    if (recipe.authorId != uid) {
      throw const RecipeFailure(RecipeFailureCode.forbidden);
    }
    cancellation.check();
    final photo = await prepareAvatar(
      bytes,
    ); // Existing verified metadata-free pipeline, <=2 MiB/1024px.
    _sameActor(uid);
    cancellation.check();
    final path = '$uid/${recipe.id}/${newRecipeRequestId()}.jpg';
    final retry = StorageRetryController();
    cancellation.onCancel = retry.cancel;
    try {
      await client.storage
          .from(bucket)
          .uploadBinary(
            path,
            photo,
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              cacheControl: '0',
              upsert: false,
            ),
            retryController: retry,
          );
    } finally {
      cancellation.onCancel = null;
    }
    cancellation.check();
    return path;
  });
  @override
  Future<void> setPhoto(Recipe recipe, String? path) => _run(() async {
    if (recipe.authorId != actor) {
      throw const RecipeFailure(RecipeFailureCode.forbidden);
    }
    await client.rpc(
      'set_recipe_photo',
      params: {
        'p_recipe_id': recipe.id,
        'p_expected_version': recipe.version,
        'p_path': path,
      },
    );
  });
  @override
  Future<Uint8List> downloadPhoto(String path) => _run(() async {
    final parts = path.split('/');
    if (parts.length != 3) throw const RecipeFailure(RecipeFailureCode.photo);
    final recipe = await read(parts[1]);
    if (recipe == null || recipe.photoPath != path) {
      throw const RecipeFailure(RecipeFailureCode.forbidden);
    }
    return client.storage.from(bucket).download(path);
  });
}
