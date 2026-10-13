// Explicit isolated local Auth/PostgREST/Storage A/B/C. Never a permission mock.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:mixtick/core/network/bounded_http_client.dart';
import 'package:mixtick/features/community/data/supabase_community_repository.dart';
import 'package:mixtick/features/community/domain/community.dart';
import 'package:mixtick/features/cook_today/data/supabase_matching_repository.dart';
import 'package:mixtick/features/cook_today/domain/matching.dart';
import 'package:mixtick/features/recipes/data/supabase_recipe_repository.dart';
import 'package:mixtick/features/recipes/domain/recipe.dart';
import 'package:mixtick/features/recipes/domain/recipe_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'recipes_local.dart' show RecipeTestPkceStorage;

const endpoint = String.fromEnvironment('SUPABASE_URL');
const publicKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
String ingredientId(int n) =>
    '10000000-0000-4000-8000-${n.toString().padLeft(12, '0')}';

class MatchingTransport extends http.BaseClient {
  final delegate = BoundedHttpClient();
  bool failNext = false;
  Completer<void>? hold, observed;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final matching = request.url.path == '/rest/v1/rpc/cook_today_page';
    if (matching && failNext) {
      failNext = false;
      throw http.ClientException('Controlled one-shot transport loss');
    }
    final response = await delegate.send(request);
    if (matching && hold != null) {
      observed?.complete();
      await hold!.future;
    }
    return response;
  }

  @override
  void close() => delegate.close();
}

class MatchingActor {
  MatchingActor(this.letter, this.suffix) {
    client = SupabaseClient(
      endpoint,
      publicKey,
      httpClient: transport,
      authOptions: AuthClientOptions(
        autoRefreshToken: false,
        pkceAsyncStorage: RecipeTestPkceStorage(),
      ),
    );
  }
  final String letter, suffix;
  final transport = MatchingTransport();
  late final SupabaseClient client;
  late final password = 'P6-test-${newRecipeRequestId()}!';
  String get email => 'mixtick-p6-$suffix-$letter@example.test';
  String? id;
  late final recipes = SupabaseRecipeRepository(client);
  late final matches = SupabaseMatchingRepository(client);
  late final social = SupabaseCommunityRepository(client);
}

void main() {
  final suffix = newRecipeRequestId().replaceAll('-', '').substring(0, 10);
  final actors = <MatchingActor>[], photos = <String>{};
  final fixtures = <String, Recipe>{};
  late MatchingActor a, b, c;
  Future<void> manifest() =>
      File('.tooling/phase06-fixtures.json').writeAsString(
        jsonEncode({
          'users': [
            for (final actor in actors)
              if (actor.id != null) {'id': actor.id, 'email': actor.email},
          ],
          'photos': photos.toList(),
        }),
      );
  Future<Recipe> fresh(Recipe recipe) async =>
      (await a.recipes.read(recipe.id))!;
  Future<Recipe> create(
    MatchingActor actor,
    String title,
    List<RecipeIngredient> items, {
    bool public = true,
    int? time,
  }) async {
    var recipe = (await actor.recipes.read(
      await actor.recipes.save(
        RecipeDraft(
          title: '$title $suffix',
          category: 'Prueba matching',
          servings: 1,
          prepMinutes: time,
          ingredients: items,
          steps: ['Paso controlado $title'],
        ),
        requestId: newRecipeRequestId(),
      ),
    ))!;
    if (public) {
      await actor.recipes.setVisibility(recipe, RecipeVisibility.public);
      recipe = (await actor.recipes.read(recipe.id))!;
    }
    fixtures[title] = recipe;
    return recipe;
  }

  RecipeIngredient line(int n, {bool optional = false, double? quantity}) =>
      RecipeIngredient(
        ingredientId: ingredientId(n),
        name: 'Catálogo $n',
        optional: optional,
        quantity: quantity,
        unit: quantity == null ? null : 'kg',
      );
  MatchingQuery query(
    List<int> ids, {
    MatchingMode mode = MatchingMode.exact,
    List<String> names = const [],
  }) => MatchingQuery([
    for (final i in ids)
      SelectedIngredient(id: ingredientId(i), name: 'Catálogo $i'),
    for (final name in names) SelectedIngredient(name: name),
  ], mode);
  Future<List<RecipeMatch>> all(MatchingActor actor, MatchingQuery q) async {
    final rows = <RecipeMatch>[];
    MatchingCursor? cursor;
    do {
      final page = await actor.matches.search(q, cursor: cursor);
      rows.addAll(page.matches);
      cursor = page.cursor;
      expect(rows.length, lessThan(100));
    } while (cursor != null);
    expect(rows.map((r) => r.recipe.id).toSet().length, rows.length);
    return rows;
  }

  bool has(List<RecipeMatch> rows, String title) =>
      rows.any((r) => r.recipe.id == fixtures[title]!.id);
  Future<void> rawInvalid(Map<String, dynamic> params) async => expectLater(
    b.client.rpc('cook_today_page', params: params),
    throwsA(isA<PostgrestException>()),
  );
  setUpAll(() async {
    if (endpoint != 'http://127.0.0.1:54321' || publicKey.isEmpty) {
      throw StateError('Only isolated local endpoint allowed');
    }
    a = MatchingActor('a', suffix);
    b = MatchingActor('b', suffix);
    c = MatchingActor('c', suffix);
    actors.addAll([a, b, c]);
    for (final actor in actors) {
      final response = await actor.client.auth.signUp(
        email: actor.email,
        password: actor.password,
      );
      expect(response.session, isNotNull);
      actor.id = response.user!.id;
      await manifest();
      await actor.client.from('profiles').insert({
        'username': 'p6_${suffix}_${actor.letter}',
        'display_name': 'Prueba matching ${actor.letter}',
      });
    }
    await create(
      a,
      'Privada A',
      [line(4), line(3), line(2, optional: true)],
      public: false,
      time: 20,
    );
    await create(a, 'Completa opcional', [
      line(4),
      line(3),
      line(2, optional: true),
    ], time: 50);
    await create(a, 'Falta uno', [
      line(4),
      line(3),
      line(33, quantity: 0.125),
    ], time: 10);
    await create(a, 'Faltan dos', [
      line(4),
      line(3),
      line(33),
      line(1),
    ], time: 5);
    await create(a, 'Faltan tres', [
      line(4),
      line(3),
      line(33),
      line(1),
      line(5),
    ], time: 1);
    await create(a, 'Sin común', [line(9)], time: 0);
    await create(a, 'Solo opcionales', [line(4, optional: true)]);
    await create(a, 'Miso blanco', [
      line(4),
      const RecipeIngredient(customName: 'Miso blanco', name: 'Miso blanco'),
    ], time: 0);
    await create(a, 'Miso rojo', [
      line(4),
      const RecipeIngredient(customName: 'Miso rojo', name: 'Miso rojo'),
    ]);
    final photoRecipe = await create(a, 'Foto pública', [
      line(4),
      line(3),
    ], time: 20);
    final bytes = img.encodePng(
      img.Image(width: 64, height: 64)..clear(img.ColorRgb8(90, 150, 45)),
    );
    final path = await a.recipes.uploadPhoto(
      photoRecipe,
      bytes,
      PhotoCancellation(),
    );
    photos.add(path);
    await manifest();
    await a.recipes.setPhoto(photoRecipe, path);
    fixtures['Foto pública'] = await fresh(photoRecipe);
    await create(b, 'Privada B', [line(4), line(3)], public: false);
    await create(c, 'Confidencial C', [
      const RecipeIngredient(
        customName: 'Clave privada confidencial',
        name: 'Clave privada confidencial',
      ),
    ], public: false);
    await create(c, 'Cantidad requerida', [line(4, quantity: 1000000)]);
  });
  tearDownAll(() async {
    await manifest();
    for (final actor in actors) {
      await actor.client.dispose();
    }
  });
  test('M07 M08 exact required subset, optional absent allowed', () async {
    final rows = await all(b, query([4, 3]));
    expect(has(rows, 'Completa opcional'), true);
    expect(rows.every((r) => r.missing == 0), true);
    final row = rows.firstWhere(
      (r) => r.recipe.id == fixtures['Completa opcional']!.id,
    );
    expect(row.required, 2);
    expect(row.matched, 2);
    expect(row.optionalMatched, 0);
  });
  test('M09 exact excludes missing required ingredients', () async {
    final rows = await all(b, query([4, 3]));
    expect(has(rows, 'Falta uno'), false);
    expect(has(rows, 'Faltan dos'), false);
  });
  test(
    'M10 missing one retains original identifier, ordinal, quantity and unit',
    () async {
      final row = (await all(
        b,
        query([4, 3], mode: MatchingMode.near),
      )).firstWhere((r) => r.recipe.id == fixtures['Falta uno']!.id);
      expect(row.missing, 1);
      expect(row.matched, 2);
      expect(
        row.transfer.lines.single.ingredient.ingredientId,
        ingredientId(33),
      );
      expect(row.transfer.lines.single.ingredient.quantity, 0.125);
      expect(row.transfer.lines.single.ingredient.unit, 'kg');
      expect(row.transfer.lines.single.ordinal, 2);
      expect(
        row.transfer.lines.single.lineId,
        matches(RegExp(r'^[0-9a-f-]{36}$')),
      );
    },
  );
  test('M11 missing two never includes optional ingredients', () async {
    final row = (await all(
      b,
      query([4, 3], mode: MatchingMode.near),
    )).firstWhere((r) => r.recipe.id == fixtures['Faltan dos']!.id);
    expect(row.missing, 2);
    expect(row.missingIngredients.length, 2);
    expect(row.missingIngredients.every((l) => !l.ingredient.optional), true);
  });
  test('M12 M13 three missing and no required overlap excluded', () async {
    final rows = await all(b, query([4, 3], mode: MatchingMode.near));
    expect(has(rows, 'Faltan tres'), false);
    expect(has(rows, 'Sin común'), false);
  });
  test(
    'M14 near missing count precedes match count and time; stable repeat',
    () async {
      final q = query([4, 3], mode: MatchingMode.near),
          rows = await all(b, query([4, 3], mode: MatchingMode.near));
      expect(
        rows.map((r) => r.missing).toList(),
        orderedEquals(rows.map((r) => r.missing).toList()..sort()),
      );
      expect(
        rows.indexWhere((r) => r.recipe.id == fixtures['Falta uno']!.id),
        lessThan(
          rows.indexWhere((r) => r.recipe.id == fixtures['Faltan dos']!.id),
        ),
      );
      expect(
        (await all(b, q)).map((r) => r.recipe.id),
        rows.map((r) => r.recipe.id),
      );
      // A faster partial with fewer required matches must not outrank the
      // recipe with greater required overlap at the same missing count.
      expect(
        rows.indexWhere((r) => r.recipe.id == fixtures['Falta uno']!.id),
        lessThan(
          rows.indexWhere((r) => r.recipe.id == fixtures['Miso blanco']!.id),
        ),
      );
    },
  );
  test(
    'M14 exact optional overlap precedes time; absent time goes last',
    () async {
      final rows = await all(b, query([4, 3, 2]));
      expect(rows.first.recipe.id, fixtures['Completa opcional']!.id);
      expect(rows.first.optionalMatched, 1);
      expect(rows.last.recipe.totalMinutes, isNull);
    },
  );
  test(
    'M02 server resolves full explicit aliases and deduplicates canonical IDs',
    () async {
      final rows = await all(b, query([4, 3], names: ['HUEVOS', 'patatas']));
      expect(has(rows, 'Completa opcional'), true);
      expect(
        rows
            .firstWhere((r) => r.recipe.id == fixtures['Completa opcional']!.id)
            .matched,
        2,
      );
      expect(
        has(
          await all(b, query([], names: ['Huevos', 'Patatas'])),
          'Completa opcional',
        ),
        true,
      );
    },
  );
  test(
    'M06 no substring, semantic, ambiguous oil or milk/cream substitution',
    () async {
      expect(
        await all(b, query([], names: ['hue', 'aceite', 'leche', 'nata'])),
        isEmpty,
      );
      expect(await all(b, query([], names: ["%' OR true --"])), isEmpty);
    },
  );
  test(
    'M16 free ingredient exact normalization, no partial/color substitution',
    () async {
      final rows = await all(b, query([4], names: [' MÍSO   blanco ']));
      expect(has(rows, 'Miso blanco'), true);
      expect(has(rows, 'Miso rojo'), false);
      expect(
        has(await all(b, query([4], names: ['miso'])), 'Miso blanco'),
        false,
      );
    },
  );
  test(
    'M17 empty and optional-only recipes do not match universally',
    () async {
      expect(
        await b.matches.search(query([])),
        isA<MatchingPage>().having((p) => p.matches, 'matches', isEmpty),
      );
      expect(await b.client.rpc('cook_today_page'), isEmpty);
      expect(
        has(
          await all(b, query([4, 3], mode: MatchingMode.near)),
          'Solo opcionales',
        ),
        false,
      );
    },
  );
  test('M18 required quantity never compared to home availability', () async {
    final row = (await all(
      b,
      query([4]),
    )).firstWhere((r) => r.recipe.id == fixtures['Cantidad requerida']!.id);
    expect(row.missing, 0);
    expect(row.matched, 1);
  });
  test('M19 own private included for A and B', () async {
    expect(has(await all(a, query([4, 3])), 'Privada A'), true);
    expect(has(await all(b, query([4, 3])), 'Privada B'), true);
  });
  test('M20 M23 foreign private title, identifier, children and counts not exposed', () async {
    final rows = await all(b, query([4, 3]));
    expect(has(rows, 'Privada A'), false);
    expect(
      rows.any(
        (r) =>
            r.recipe.authorId == c.id &&
            r.recipe.visibility == RecipeVisibility.private,
      ),
      false,
    );
    expect(
      await all(b, query([], names: ['Clave privada confidencial'])),
      isEmpty,
    );
    expect(
      await b.client
          .from('recipe_ingredients')
          .select()
          .eq('recipe_id', fixtures['Privada A']!.id),
      isEmpty,
    );
  });
  test('M15 saved public references never duplicate recipes', () async {
    final recipe = fixtures['Foto pública']!;
    await b.social.save(recipe.id, true);
    expect(
      (await all(
        b,
        query([4, 3]),
      )).where((r) => r.recipe.id == recipe.id).length,
      1,
    );
    expect(
      (await b.social.load(const CommunityQuery(saved: true)))
          .entries
          .single
          .recipe
          .id,
      recipe.id,
    );
  });
  test('M21 symmetric author block excludes matching and photo; C remains authorized', () async {
    await b.social.block(a.id!, true);
    expect(
      (await all(b, query([4, 3]))).any((r) => r.recipe.authorId == a.id),
      false,
    );
    expect(
      (await all(a, query([4, 3]))).any((r) => r.recipe.authorId == b.id),
      false,
    );
    expect(has(await all(c, query([4, 3])), 'Foto pública'), true);
    await expectLater(
      b.recipes.downloadPhoto(fixtures['Foto pública']!.photoPath!),
      throwsA(isA<RecipeFailure>()),
    );
    await b.social.block(a.id!, false);
  });
  test(
    'M22 saved marker cannot retain recipe/children/photo after privatization',
    () async {
      final recipe = await fresh(fixtures['Foto pública']!);
      await a.recipes.setVisibility(recipe, RecipeVisibility.private);
      expect(has(await all(b, query([4, 3])), 'Foto pública'), false);
      expect(await b.recipes.read(recipe.id), isNull);
      await expectLater(
        b.recipes.downloadPhoto(recipe.photoPath!),
        throwsA(isA<RecipeFailure>()),
      );
      expect(has(await all(a, query([4, 3])), 'Foto pública'), true);
      await a.recipes.setVisibility(
        await fresh(recipe),
        RecipeVisibility.public,
      );
    },
  );
  test(
    'M25 multiple pages have no duplicates across own/public/saved sources',
    () async {
      for (var i = 0; i < 9; i++) {
        await create(b, 'Página $i', [line(4)], time: 30 + i);
      }
      final q = query([4, 3]);
      final first = await b.matches.search(q);
      expect(first.matches.length, 8);
      expect(first.cursor, isNotNull);
      final rows = await all(b, q);
      expect(rows.length, greaterThan(9));
      expect(rows.where((r) => r.recipe.authorId == b.id).length, 10);
    },
  );
  test('M30 edits and deletion reconcile new matches while community still reads original', () async {
    var recipe = await fresh(fixtures['Falta uno']!);
    await a.recipes.save(
      RecipeDraft(
        title: recipe.title,
        category: recipe.category,
        servings: 1,
        ingredients: [line(4), line(3)],
        steps: ['Paso modificado'],
      ),
      previous: recipe,
      requestId: newRecipeRequestId(),
    );
    expect(has(await all(b, query([4, 3])), 'Falta uno'), true);
    expect((await b.social.entry(recipe.id))!.recipe.id, recipe.id);
    recipe = await fresh(recipe);
    await a.recipes.delete(recipe);
    expect(has(await all(b, query([4, 3])), 'Falta uno'), false);
  });
  test('M33 server rejects excessive inputs, null, unknown UUID, invalid mode/limit/cursor', () async {
    for (final params in <Map<String, dynamic>>[
      {
        'p_ids': [newRecipeRequestId()],
      },
      {'p_ids': null},
      {'p_names': null},
      {
        'p_names': ['\n\t '],
      },
      {
        'p_names': ['x' * 81],
      },
      {'p_names': List.filled(51, 'Miso')},
      {'p_mode': 'inventory'},
      {'p_mode': null},
      {'p_limit': 0},
      {'p_limit': 51},
      {
        'p_after': {'id': newRecipeRequestId()},
      },
      {'p_after': []},
      {
        'p_after': {
          'missing': 0,
          'rank': 0,
          'minutes': 0,
          'id': newRecipeRequestId(),
          'query': 'unsafe',
        },
      },
    ]) {
      await rawInvalid(params);
    }
  });
  test('M33 anonymous RPC denied', () async {
    final anon = SupabaseClient(
      endpoint,
      publicKey,
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
    try {
      await expectLater(
        anon.rpc(
          'cook_today_page',
          params: {
            'p_names': ['Huevos'],
          },
        ),
        throwsA(isA<PostgrestException>()),
      );
    } finally {
      await anon.dispose();
    }
  });
  test(
    'M27 hybrid one-shot transport failure then real server recovery',
    () async {
      b.transport.failNext = true;
      await expectLater(
        b.matches.search(query([4])),
        throwsA(
          isA<MatchingFailure>().having(
            (e) => e.code,
            'code',
            MatchingFailureCode.network,
          ),
        ),
      );
      expect((await b.matches.search(query([4]))).matches, isNotEmpty);
    },
  );
  test('M24 hybrid real response held during real B to C identity change is discarded', () async {
    b.transport.hold = Completer<void>();
    b.transport.observed = Completer<void>();
    final pending = b.matches.search(query([4, 3]));
    final assertion = expectLater(
      pending,
      throwsA(
        isA<MatchingFailure>().having(
          (e) => e.code,
          'code',
          MatchingFailureCode.forbidden,
        ),
      ),
    );
    await b.transport.observed!.future.timeout(const Duration(seconds: 10));
    await b.client.auth.signOut(scope: SignOutScope.local);
    await b.client.auth.signInWithPassword(
      email: c.email,
      password: c.password,
    );
    b.transport.hold!.complete();
    await assertion;
    b.transport.hold = null;
    b.transport.observed = null;
    await b.client.auth.signOut(scope: SignOutScope.local);
    await b.client.auth.signInWithPassword(
      email: b.email,
      password: b.password,
    );
  });
}
