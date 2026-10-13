// Explicit real local Auth/PostgREST/Storage integration suite. No RLS mocks.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mixtick/core/network/bounded_http_client.dart';
import 'package:mixtick/features/recipes/data/supabase_recipe_repository.dart';
import 'package:mixtick/features/recipes/domain/recipe.dart';
import 'package:mixtick/features/recipes/domain/recipe_repository.dart';

const endpoint = String.fromEnvironment('SUPABASE_URL');
const publicKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
const tomatoId = '10000000-0000-4000-8000-000000000001';
const eggId = '10000000-0000-4000-8000-000000000004';

class RecipeTestPkceStorage extends GotrueAsyncStorage {
  final values = <String, String>{};
  @override
  Future<String?> getItem({required String key}) async => values[key];
  @override
  Future<void> setItem({required String key, required String value}) async {
    values[key] = value;
  }

  @override
  Future<void> removeItem({required String key}) async {
    values.remove(key);
  }
}

// Inject one lost response after a successful REAL server transaction. This
// case proves retry reconciliation; it is not counted as another RLS check.
class LostCreationResponse extends http.BaseClient {
  final delegate = BoundedHttpClient();
  bool lose = true;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final response = await delegate.send(request);
    if (lose &&
        request.url.path == '/rest/v1/rpc/create_recipe_once' &&
        response.statusCode == 200) {
      lose = false;
      await response.stream.drain<void>();
      throw http.ClientException('Controlled lost creation response');
    }
    return response;
  }

  @override
  void close() => delegate.close();
}

class RecipeActor {
  RecipeActor(this.letter, this.suffix)
    : client = SupabaseClient(
        endpoint,
        publicKey,
        httpClient: BoundedHttpClient(),
        authOptions: AuthClientOptions(
          autoRefreshToken: false,
          pkceAsyncStorage: RecipeTestPkceStorage(),
        ),
      );
  final String letter, suffix;
  final SupabaseClient client;
  String get email => 'mixtick-p4-$suffix-$letter@example.test';
  late final password = 'P4-fixture-${newRecipeRequestId()}!';
  String? id;
  late final repo = SupabaseRecipeRepository(client);
}

RecipeDraft richDraft([String title = 'Tortilla local']) => RecipeDraft(
  title: title,
  category: 'Principal',
  description: 'Solo para las pruebas locales',
  servings: 2.5,
  prepMinutes: 10,
  cookMinutes: 20,
  ingredients: const [
    RecipeIngredient(
      ingredientId: tomatoId,
      name: 'Tomate',
      quantity: 1.25,
      unit: 'kg',
    ),
    RecipeIngredient(
      ingredientId: eggId,
      name: 'Huevo',
      quantity: 2,
      unit: 'ud',
    ),
    RecipeIngredient(
      customName: 'Hierba única de prueba',
      name: 'Hierba única de prueba',
      quantity: 0.125,
      unit: 'cucharada',
      optional: true,
    ),
  ],
  steps: ['Preparar los ingredientes.', 'Cocer.', 'Servir.'],
);
Future<Recipe> fresh(RecipeActor actor, String id) async =>
    (await actor.repo.read(id))!;
Map<String, dynamic> saveParams(Recipe recipe, RecipeDraft draft) => {
  'p_recipe_id': recipe.id,
  'p_expected_version': recipe.version,
  'p_recipe': draft.header,
  'p_ingredients': draft.ingredients.map((i) => i.toJson()).toList(),
  'p_steps': draft.steps,
};
Matcher failure(RecipeFailureCode code) =>
    throwsA(isA<RecipeFailure>().having((e) => e.code, 'code', code));
void main() {
  final suffix = newRecipeRequestId().replaceAll('-', '').substring(0, 10);
  late RecipeActor a, b, c;
  final actors = <RecipeActor>[];
  final photos = <String>{};
  final png = img.encodePng(
    img.Image(width: 32, height: 32)..clear(img.ColorRgb8(45, 125, 80)),
  );
  late Recipe base, concurrent, idempotent;
  late String originalPhoto, replacementPhoto, idempotentRequest;
  Future<void> writeFixtures() async {
    await File('.tooling/phase04-fixtures.json').writeAsString(
      jsonEncode({
        'suffix': suffix,
        'users': [
          for (final actor in actors)
            if (actor.id != null) {'id': actor.id, 'email': actor.email},
        ],
        'photos': photos.toList(),
      }),
    );
  }

  setUpAll(() async {
    if (endpoint != 'http://127.0.0.1:54321' || publicKey.isEmpty) {
      throw StateError('Only isolated local endpoint permitted');
    }
    a = RecipeActor('a', suffix);
    b = RecipeActor('b', suffix);
    c = RecipeActor('c', suffix);
    actors.addAll([a, b, c]);
    for (final actor in actors) {
      final response = await actor.client.auth.signUp(
        email: actor.email,
        password: actor.password,
      );
      expect(
        response.session,
        isNotNull,
        reason: 'Local auto-confirm is required',
      );
      actor.id = response.user!.id;
      await writeFixtures();
      await actor.client.from('profiles').insert({
        'username': 'p4_${suffix}_${actor.letter}',
        'display_name': 'Prueba ${actor.letter.toUpperCase()}',
      });
    }
  });
  tearDownAll(() async {
    await writeFixtures();
    for (final actor in actors) {
      await actor.client.dispose();
    }
  });
  test(
    'R01 create effective private defaults with a real authenticated client',
    () async {
      final id = await a.repo.save(
        richDraft(),
        requestId: newRecipeRequestId(),
      );
      base = await fresh(a, id);
      expect(base.visibility, RecipeVisibility.private);
      expect(base.authorId, a.id);
      expect(await b.repo.read(id), isNull);
      expect(await c.repo.read(id), isNull);
    },
  );
  test(
    'R02 R03 R04 full aggregate, numeric precision, servings and times persist',
    () async {
      expect((await a.repo.resolveIngredient('  tOMÁTES  '))!.id, tomatoId);
      expect(await a.repo.resolveIngredient('Hierba única de prueba'), isNull);
      final result = await fresh(a, base.id);
      expect(result.ingredients.length, 3);
      expect(result.steps, ['Preparar los ingredientes.', 'Cocer.', 'Servir.']);
      expect(result.ingredients[0].ingredientId, tomatoId);
      expect(result.ingredients[0].quantity, 1.25);
      expect(result.ingredients[0].unit, 'kg');
      expect(result.servings, 2.5);
      expect(result.prepMinutes, 10);
      expect(result.cookMinutes, 20);
      expect(result.totalMinutes, 30);
    },
  );
  test('R05 R06 R07 atomic editing reorders steps and persists optional ingredients', () async {
    final draft = RecipeDraft(
      title: 'Tortilla editada',
      description: 'Actualizada',
      category: 'Cena',
      servings: 3,
      prepMinutes: 5,
      cookMinutes: 15,
      ingredients: richDraft().ingredients,
      steps: ['Servir.', 'Cocer.', 'Preparar los ingredientes.'],
    );
    await a.repo.save(draft, previous: base, requestId: newRecipeRequestId());
    base = await fresh(a, base.id);
    expect(base.title, draft.title);
    expect(base.category, 'Cena');
    expect(base.servings, 3);
    expect(base.steps, draft.steps);
    expect(base.ingredients.last.optional, true);
    expect(base.version, 2);
  });
  test(
    'R13 valid photo is reencoded and uploaded to the private bucket',
    () async {
      originalPhoto = await a.repo.uploadPhoto(base, png, PhotoCancellation());
      photos.add(originalPhoto);
      await writeFixtures();
      await a.repo.setPhoto(base, originalPhoto);
      base = await fresh(a, base.id);
      final downloaded = await a.repo.downloadPhoto(originalPhoto);
      expect(downloaded.take(3), [255, 216, 255]);
      expect(img.decodeJpg(downloaded), isNotNull);
      await expectLater(
        b.repo.downloadPhoto(originalPhoto),
        failure(RecipeFailureCode.forbidden),
      );
      await expectLater(
        c.client.storage.from('recipe-photos').download(originalPhoto),
        throwsA(isA<StorageException>()),
      );
    },
  );
  test(
    'R14 reject invalid/oversize data and cancelled uploads before Storage',
    () async {
      await expectLater(
        a.repo.uploadPhoto(
          base,
          Uint8List.fromList([1, 2, 3, 4]),
          PhotoCancellation(),
        ),
        failure(RecipeFailureCode.photo),
      );
      await expectLater(
        a.repo.uploadPhoto(base, Uint8List(2097153), PhotoCancellation()),
        failure(RecipeFailureCode.photo),
      );
      final cancelled = PhotoCancellation()..cancel();
      await expectLater(
        a.repo.uploadPhoto(base, png, cancelled),
        failure(RecipeFailureCode.cancelled),
      );
      expect((await fresh(a, base.id)).photoPath, originalPhoto);
    },
  );
  test('R08 publish uses explicit server operation; B/C see full authorized aggregate', () async {
    await a.repo.setVisibility(base, RecipeVisibility.public);
    base = await fresh(a, base.id);
    for (final other in [b, c]) {
      final readable = (await other.repo.read(base.id))!;
      expect(readable.ingredients.length, 3);
      expect(readable.steps.length, 3);
      expect(await other.repo.downloadPhoto(originalPhoto), isNotEmpty);
    }
  });
  test(
    'R15 public staging and replaced photos hidden from third parties',
    () async {
      replacementPhoto = await a.repo.uploadPhoto(
        base,
        png,
        PhotoCancellation(),
      );
      photos.add(replacementPhoto);
      await writeFixtures();
      await expectLater(
        b.client.storage.from('recipe-photos').download(replacementPhoto),
        throwsA(isA<StorageException>()),
      );
      expect(await b.repo.downloadPhoto(originalPhoto), isNotEmpty);
      await a.repo.setPhoto(base, replacementPhoto);
      base = await fresh(a, base.id);
      expect(await b.repo.downloadPhoto(replacementPhoto), isNotEmpty);
      await expectLater(
        b.client.storage.from('recipe-photos').download(originalPhoto),
        throwsA(isA<StorageException>()),
      );
      final listed = await b.client.storage
          .from('recipe-photos')
          .list(path: '${a.id}/${base.id}');
      expect(listed.map((o) => o.name), [replacementPhoto.split('/').last]);
      await a.repo.setPhoto(base, null);
      base = await fresh(a, base.id);
      expect(base.photoPath, isNull);
      await expectLater(
        c.client.storage.from('recipe-photos').download(replacementPhoto),
        throwsA(isA<StorageException>()),
      );
      await a.repo.setPhoto(base, replacementPhoto);
      base = await fresh(a, base.id);
    },
  );
  test('R09 privatizing denies current header, child rows, downloads and new signatures', () async {
    await a.repo.setVisibility(base, RecipeVisibility.private);
    base = await fresh(a, base.id);
    for (final other in [b, c]) {
      expect(await other.repo.read(base.id), isNull);
      for (final table in ['recipe_ingredients', 'recipe_steps']) {
        expect(
          await other.client.from(table).select().eq('recipe_id', base.id),
          isEmpty,
        );
      }
      await expectLater(
        other.client.storage.from('recipe-photos').download(replacementPhoto),
        throwsA(isA<StorageException>()),
      );
      await expectLater(
        other.client.storage
            .from('recipe-photos')
            .createSignedUrl(replacementPhoto, 60),
        throwsA(isA<StorageException>()),
      );
    }
  });
  test('R10 raw RPC, direct mutation, child write and foreign path spoof all denied', () async {
    await expectLater(
      b.client.rpc(
        'save_recipe',
        params: saveParams(base, richDraft('Intrusion')),
      ),
      throwsA(isA<PostgrestException>().having((e) => e.code, 'code', '42501')),
    );
    await expectLater(
      c.client.rpc(
        'set_recipe_visibility',
        params: {
          'p_recipe_id': base.id,
          'p_expected_version': base.version,
          'p_visibility': 'public',
        },
      ),
      throwsA(isA<PostgrestException>().having((e) => e.code, 'code', '42501')),
    );
    await expectLater(
      b.client.from('recipes').update({'title': 'Intrusion'}).eq('id', base.id),
      throwsA(isA<PostgrestException>()),
    );
    await expectLater(
      b.client.from('recipe_steps').insert({
        'recipe_id': base.id,
        'instruction': 'Intrusion',
        'sort_order': 5,
      }),
      throwsA(isA<PostgrestException>()),
    );
    await expectLater(
      b.client.storage
          .from('recipe-photos')
          .uploadBinary(
            '${a.id}/${base.id}/${newRecipeRequestId()}.png',
            png,
            fileOptions: const FileOptions(contentType: 'image/png'),
          ),
      throwsA(isA<StorageException>()),
    );
    await expectLater(
      b.client.rpc(
        'delete_recipe_versioned',
        params: {'p_recipe_id': base.id, 'p_expected_version': base.version},
      ),
      throwsA(isA<PostgrestException>().having((e) => e.code, 'code', '42501')),
    );
    expect((await fresh(a, base.id)).title, base.title);
  });
  test(
    'R17 rejected aggregate rolls back header, version and children together',
    () async {
      final before = await a.client
          .from('recipes')
          .select(SupabaseRecipeRepository.detailColumns)
          .eq('id', base.id)
          .single();
      final params = saveParams(base, richDraft('Must roll back'));
      params['p_steps'] = ['Good step', '   '];
      await expectLater(
        a.client.rpc('save_recipe', params: params),
        throwsA(isA<PostgrestException>()),
      );
      final after = await a.client
          .from('recipes')
          .select(SupabaseRecipeRepository.detailColumns)
          .eq('id', base.id)
          .single();
      expect(after, before);
      final countBefore =
          (await a.client.from('recipes').select('id').eq('author_id', a.id!))
              .length;
      params['p_recipe_id'] = null;
      params['p_expected_version'] = null;
      await expectLater(
        a.client.rpc('save_recipe', params: params),
        throwsA(isA<PostgrestException>()),
      );
      expect(
        (await a.client.from('recipes').select('id').eq('author_id', a.id!))
            .length,
        countBefore,
      );
    },
  );
  test('R18 two actual concurrent edits produce one success and one version conflict', () async {
    concurrent = await fresh(
      a,
      await a.repo.save(
        richDraft('Concurrent original'),
        requestId: newRecipeRequestId(),
      ),
    );
    final results = await Future.wait([
      for (final title in ['Concurrent first', 'Concurrent second'])
        () async {
          try {
            await a.repo.save(
              richDraft(title),
              previous: concurrent,
              requestId: newRecipeRequestId(),
            );
            return 'ok';
          } on RecipeFailure catch (error) {
            return error.code.name;
          }
        }(),
    ]);
    expect(results.where((s) => s == 'ok').length, 1);
    expect(results.where((s) => s == 'conflict').length, 1);
    final actual = await fresh(a, concurrent.id);
    expect(actual.version, 2);
    expect(actual.ingredients.length, 3);
    expect(actual.steps.length, 3);
    await expectLater(
      a.repo.delete(concurrent),
      failure(RecipeFailureCode.conflict),
    );
  });
  test('R17 concurrent retry-safe creation makes one private aggregate and isolates request lookup', () async {
    idempotentRequest = newRecipeRequestId();
    final ids = await Future.wait([
      a.repo.save(richDraft('Idempotent'), requestId: idempotentRequest),
      a.repo.save(richDraft('Idempotent'), requestId: idempotentRequest),
    ]);
    expect(ids[0], ids[1]);
    idempotent = await fresh(a, ids.first);
    expect(idempotent.visibility, RecipeVisibility.private);
    expect(await a.repo.lookupCreation(idempotentRequest), idempotent.id);
    expect(await b.repo.lookupCreation(idempotentRequest), isNull);
    await expectLater(
      a.repo.save(
        richDraft('Different retry payload'),
        requestId: idempotentRequest,
      ),
      failure(RecipeFailureCode.conflict),
    );
  });
  test('R12 own title/category/privacy filters and keyset pagination without duplicate records', () async {
    for (var i = 0; i < 6; i++) {
      await a.repo.save(
        richDraft(i == 0 ? 'Lote 50%_receta' : 'Lote $i'),
        requestId: newRecipeRequestId(),
      );
    }
    await b.repo.save(
      richDraft('Lote other author'),
      requestId: newRecipeRequestId(),
    );
    final page = await a.repo.loadMine(const RecipeFilter());
    expect(page.recipes.length, 8);
    expect(page.cursor, isNotNull);
    final next = await a.repo.loadMine(
      const RecipeFilter(),
      cursor: page.cursor,
    );
    expect(next.recipes.length, 1);
    expect(next.cursor, isNull);
    expect(
      {
        ...page.recipes.map((r) => r.id),
        ...next.recipes.map((r) => r.id),
      }.length,
      9,
    );
    for (var i = 1; i < page.recipes.length; i++) {
      expect(
        page.recipes[i - 1].updatedAt.isBefore(page.recipes[i].updatedAt),
        false,
      );
    }
    final filtered = await a.repo.loadMine(
      const RecipeFilter(
        search: 'Lote',
        category: 'Principal',
        visibility: RecipeVisibility.private,
      ),
    );
    expect(filtered.recipes.length, 6);
    expect(filtered.recipes.every((r) => r.authorId == a.id), true);
    final literal = await a.repo.loadMine(const RecipeFilter(search: '50%_'));
    expect(literal.recipes.single.title, 'Lote 50%_receta');
    expect(await a.repo.loadCategories(), ['Cena', 'Principal']);
  });
  test('R16 hybrid: lose a real committed creation response then retry without duplication', () async {
    final transport = LostCreationResponse();
    final client = SupabaseClient(
      endpoint,
      publicKey,
      httpClient: transport,
      authOptions: AuthClientOptions(
        autoRefreshToken: false,
        pkceAsyncStorage: RecipeTestPkceStorage(),
      ),
    );
    try {
      await client.auth.signInWithPassword(
        email: a.email,
        password: a.password,
      );
      final repository = SupabaseRecipeRepository(client);
      final request = newRecipeRequestId();
      final draft = richDraft('Actual committed response lost');
      final countBefore = (await a.repo.loadMine(
        const RecipeFilter(search: 'Actual committed response lost'),
      )).recipes.length;
      await expectLater(
        repository.save(draft, requestId: request),
        failure(RecipeFailureCode.network),
      );
      final id = await repository.lookupCreation(request);
      expect(id, isNotNull);
      expect(
        (await repository.read(id!))!.visibility,
        RecipeVisibility.private,
      );
      expect(await repository.save(draft, requestId: request), id);
      expect(
        (await a.repo.loadMine(
          const RecipeFilter(search: 'Actual committed response lost'),
        )).recipes.length,
        countBefore + 1,
      );
    } finally {
      await client.dispose();
      transport.close();
    }
  });
  test('R19 actual account switch scopes subsequent reads and rejects previous private photograph', () async {
    await a.client.auth.signOut();
    await a.client.auth.signInWithPassword(
      email: b.email,
      password: b.password,
    );
    final own = await a.repo.loadMine(const RecipeFilter());
    expect(own.recipes.every((r) => r.authorId == b.id), true);
    expect(await a.repo.read(base.id), isNull);
    await expectLater(
      a.repo.downloadPhoto(replacementPhoto),
      failure(RecipeFailureCode.forbidden),
    );
    await a.client.auth.signOut();
    await a.client.auth.signInWithPassword(
      email: a.email,
      password: a.password,
    );
    expect((await fresh(a, base.id)).authorId, a.id);
  });
  test('R11 versioned deletion removes aggregate relations; photos inaccessible; retry cannot resurrect', () async {
    base = await fresh(a, base.id);
    await a.repo.delete(base);
    expect(await a.repo.read(base.id), isNull);
    for (final table in ['recipe_ingredients', 'recipe_steps']) {
      expect(
        await a.client.from(table).select().eq('recipe_id', base.id),
        isEmpty,
      );
    }
    await expectLater(
      a.client.storage.from('recipe-photos').download(replacementPhoto),
      throwsA(isA<StorageException>()),
    );
    await a.repo.delete(idempotent);
    await expectLater(
      a.repo.save(richDraft('Idempotent'), requestId: idempotentRequest),
      failure(RecipeFailureCode.conflict),
    );
    expect(await a.repo.lookupCreation(idempotentRequest), isNull);
  });
}
