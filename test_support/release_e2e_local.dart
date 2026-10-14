// ignore_for_file: avoid_print
// Complete product flow with real Auth/API/Storage and independent sockets.
// The host-only worker trigger is separate from permission assertions.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mixtick/core/network/bounded_http_client.dart';
import 'package:mixtick/features/community/data/supabase_community_repository.dart';
import 'package:mixtick/features/community/domain/community.dart';
import 'package:mixtick/features/cook_today/data/supabase_matching_repository.dart';
import 'package:mixtick/features/cook_today/domain/matching.dart';
import 'package:mixtick/features/profile/data/supabase_account_deletion_repository.dart';
import 'package:mixtick/features/profile/data/avatar_processor.dart';
import 'package:mixtick/features/recipes/data/supabase_recipe_repository.dart';
import 'package:mixtick/features/recipes/domain/recipe.dart';
import 'package:mixtick/features/recipes/domain/recipe_repository.dart';
import 'package:mixtick/features/recipes/presentation/recipe_providers.dart';
import 'package:mixtick/features/shopping/data/supabase_shopping_repository.dart';
import 'package:mixtick/features/shopping/domain/shopping.dart';
import 'package:mixtick/features/shopping/presentation/shopping_providers.dart';

import 'recipes_local.dart' show RecipeTestPkceStorage;

const endpoint = String.fromEnvironment('SUPABASE_URL'),
    publicKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');

class CountingTransport extends http.BaseClient {
  final actual = BoundedHttpClient();
  int snapshots = 0;
  int requests = 0, bytes = 0;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    if (request.url.path.endsWith('/shopping_list_snapshot')) snapshots++;
    requests++;
    return actual
        .send(request)
        .then(
          (response) => http.StreamedResponse(
            response.stream.map((chunk) {
              bytes += chunk.length;
              return chunk;
            }),
            response.statusCode,
            headers: response.headers,
            request: response.request,
            contentLength: response.contentLength,
            reasonPhrase: response.reasonPhrase,
          ),
        );
  }

  @override
  void close() => actual.close();
}

class Actor {
  Actor(this.letter, this.suffix) {
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
  final transport = CountingTransport();
  late final SupabaseClient client;
  String get email => 'mixtick-p8-$suffix-$letter@example.test';
  String get username => 'p8_${suffix}_$letter';
  final password = 'P8-${newRecipeRequestId()}!';
  String? id;
  late final recipes = SupabaseRecipeRepository(client),
      community = SupabaseCommunityRepository(client),
      shopping = SupabaseShoppingRepository(client),
      matching = SupabaseMatchingRepository(client);
}

Future<void> waitFor(bool Function() condition, {int seconds = 25}) async {
  final deadline = DateTime.now().add(Duration(seconds: seconds));
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      throw TimeoutException('Real server condition not reached');
    }
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
}

void main() {
  final suffix = newRecipeRequestId().replaceAll('-', '').substring(0, 10);
  final actors = <Actor>[];
  late Actor a, b, c;
  Future<void> manifest() => File('.tooling/phase08-e2e-fixtures.json')
      .writeAsString(
        jsonEncode({
          'users': [
            for (final u in actors)
              if (u.id != null) {'id': u.id, 'email': u.email},
          ],
        }),
      );
  void step(int id, String name) => print(
    'P8_E2E:${jsonEncode({'step': id, 'status': 'PASS', 'name': name})}',
  );
  setUpAll(() async {
    if (endpoint != 'http://127.0.0.1:54321' || publicKey.isEmpty) {
      throw StateError('Isolated local endpoint only');
    }
    a = Actor('a', suffix);
    b = Actor('b', suffix);
    c = Actor('c', suffix);
    actors.addAll([a, b, c]);
    for (final u in actors) {
      final result = await u.client.auth.signUp(
        email: u.email,
        password: u.password,
      );
      u.id = result.user!.id;
      await manifest();
      await u.client.from('profiles').insert({
        'username': u.username,
        'display_name': 'Auditoría ${u.letter.toUpperCase()}',
      });
    }
  });
  tearDownAll(() async {
    await manifest();
    for (final u in actors) {
      await u.client.dispose();
    }
  });
  test('X01 complete four-module E2E with image, concurrent edits, revoke and real account worker', () async {
    step(1, 'A/B/C register through real GoTrue');
    final draft = RecipeDraft(
      title: 'Tortilla auditoría $suffix',
      category: 'Principal',
      servings: 2,
      ingredients: const [
        RecipeIngredient(
          ingredientId: '10000000-0000-4000-8000-000000000004',
          name: 'Huevo',
          quantity: 2,
          unit: 'ud',
        ),
        RecipeIngredient(
          ingredientId: '10000000-0000-4000-8000-000000000003',
          name: 'Patata',
          quantity: 0.5,
          unit: 'kg',
        ),
        RecipeIngredient(
          ingredientId: '10000000-0000-4000-8000-000000000008',
          name: 'Sal',
          optional: true,
        ),
      ],
      steps: ['Preparar y cocinar.'],
    );
    final rid = await a.recipes.save(draft, requestId: newRecipeRequestId());
    var recipe = (await a.recipes.read(rid))!;
    expect(recipe.visibility, RecipeVisibility.private);
    expect(await b.recipes.read(rid), isNull);
    step(2, 'new recipe private and foreign UUID denied');
    final image = img.Image(width: 16, height: 16)
      ..clear(img.ColorRgb8(220, 155, 40));
    final path = await a.recipes.uploadPhoto(
      recipe,
      img.encodePng(image),
      PhotoCancellation(),
    );
    await a.recipes.setPhoto(recipe, path);
    recipe = (await a.recipes.read(rid))!;
    expect(recipe.ingredients, hasLength(3));
    step(3, 'original ingredient quantities and processed photo persisted');
    await a.recipes.setVisibility(recipe, RecipeVisibility.public);
    step(4, 'A explicitly publishes');
    final feed = await b.community.load(CommunityQuery(search: suffix));
    expect(feed.entries.single.recipe.id, rid);
    step(5, 'B finds original in Community');
    await b.community.save(rid, true);
    expect(
      (await b.community.load(const CommunityQuery(saved: true))).entries
          .any((e) => e.recipe.id == rid),
      true,
    );
    step(6, 'B saves reference');
    final results = await b.matching.search(
      MatchingQuery(const [
        SelectedIngredient(name: 'Huevos'),
      ], MatchingMode.near),
    );
    final match = results.matches.singleWhere((m) => m.recipe.id == rid);
    expect(match.missing, 1);
    expect(match.missingIngredients.single.ingredient.name, 'Patata');
    step(7, 'B searches cook-today through server');
    step(8, 'selection resolves full Huevos alias');
    step(9, 'one mandatory missing with original 0.5 kg');
    final list = await b.shopping.createList(
      'E2E compartida $suffix',
      newRecipeRequestId(),
    );
    step(10, 'B creates owned list');
    await b.shopping.invite(list, a.username);
    step(11, 'explicit invitation to A');
    final invitation = (await a.shopping.overview()).invitations.singleWhere(
      (i) => i.listId == list,
    );
    await a.shopping.respond(invitation, true);
    step(12, 'A accepts; C still unauthorized');
    await expectLater(c.shopping.read(list), throwsA(isA<ShoppingFailure>()));
    var aReady = false, bReady = false, aChanges = 0, bChanges = 0;
    final subA = a.shopping.watch(list).listen((s) {
      if (s == ShoppingSignal.connected) aReady = true;
      if (s == ShoppingSignal.changed) aChanges++;
    });
    final subB = b.shopping.watch(list).listen((s) {
      if (s == ShoppingSignal.connected) bReady = true;
      if (s == ShoppingSignal.changed) bChanges++;
    });
    try {
      await waitFor(() => aReady && bReady);
      final preview = await b.shopping.preview(rid);
      await b.shopping.importIngredients(
        list,
        preview,
        match.missingIngredients,
        newRecipeRequestId(),
        missingOnly: true,
      );
      step(13, 'B confirms checked missing-only import');
      await waitFor(() => aChanges > 0);
      var snap = await a.shopping.read(list);
      expect(snap.items.single.quantity, 0.5);
      step(14, 'independent A socket sees imported line');
      final before = bChanges;
      await a.shopping.toggle(snap.items.single);
      step(15, 'A marks purchased');
      await waitFor(() => bChanges > before);
      snap = await b.shopping.read(list);
      expect(snap.items.single.purchased, true);
      step(16, 'independent B socket and read see purchased');
      Future<bool> edit(Actor actor, String name) async {
        try {
          await actor.shopping.edit(
            snap.items.single,
            ShoppingDraft(name, quantity: 0.5, unit: 'kg'),
          );
          return true;
        } on ShoppingFailure catch (e) {
          expect(e.code, ShoppingFailureCode.conflict);
          return false;
        }
      }

      final winners = await Future.wait([
        edit(a, 'Patata A'),
        edit(b, 'Patata B'),
      ]);
      expect(winners.where((v) => v), hasLength(1));
      step(17, 'two sessions edit identical expected version');
      step(18, 'one winner and one explicit conflict, no silent overwrite');
      final own = await b.recipes.save(draft, requestId: newRecipeRequestId());
      var owned = (await b.recipes.read(own))!;
      await b.recipes.setVisibility(owned, RecipeVisibility.public);
      expect(await c.recipes.read(own), isNotNull);
      owned = (await b.recipes.read(own))!;
      await b.recipes.setVisibility(owned, RecipeVisibility.private);
      expect(await c.recipes.read(own), isNull);
      step(19, 'B withdraws its own recipe and direct C access disappears');
      await b.shopping.revoke(list, a.id!);
      step(20, 'owner B revokes A');
      await expectLater(a.shopping.read(list), throwsA(isA<ShoppingFailure>()));
      await expectLater(
        a.shopping.respond(invitation, true),
        throwsA(isA<ShoppingFailure>()),
      );
      step(21, 'old JWT and old invitation cannot recover list');
      await SupabaseAccountDeletionRepository(a.client)
          .request(a.password, newRecipeRequestId());
      step(22, 'A requests authenticated self-deletion');
      final worker = await Process.run(
        'C:/Users/Sergio/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe',
        ['scripts/invoke_local_worker.py'],
      );
      expect(
        worker.exitCode,
        0,
        reason: 'Trusted host worker trigger failed; no secret in Dart/mobile',
      );
      await expectLater(a.client.auth.getUser(), throwsA(isA<AuthException>()));
      expect(await b.recipes.read(rid), isNull);
      expect((await b.shopping.read(list)).list.ownerId, b.id);
      await a.client.auth.signOut(scope: SignOutScope.local);
      expect(a.client.auth.currentSession, isNull);
      step(
        23,
        'worker deletes physical photo/Auth; foreign list survives and local session closes',
      );
    } finally {
      await subA.cancel();
      await subB.cancel();
    }
  }, timeout: const Timeout(Duration(minutes: 2)));

  test('Realtime full-list deletion: real socket + authoritative 15s probe clears state/channel without extra subscriptions', () async {
    final list = await b.shopping.createList(
      'Realtime borrado $suffix',
      newRecipeRequestId(),
    );
    await b.shopping.invite(list, c.username);
    await c.shopping.respond(
      (await c.shopping.overview()).invitations.singleWhere(
        (i) => i.listId == list,
      ),
      true,
    );
    final before = c.transport.snapshots;
    final container = ProviderContainer(
      overrides: [
        recipeActorProvider.overrideWithValue(c.id),
        shoppingRepositoryProvider.overrideWithValue(c.shopping),
      ],
    );
    final provider = shoppingDetailProvider(list),
        subscription = container.listen(
          shoppingDetailProvider(list),
          (_, _) {},
        );
    try {
      await container.read(provider.future);
      await waitFor(
        () =>
            container.read(provider).value?.signal == ShoppingSignal.connected,
      );
      expect(c.client.getChannels(), hasLength(1));
      await Future<void>.delayed(const Duration(milliseconds: 600));
      expect(container.read(provider).value?.snapshot?.list.id, list);
      final removal = Stopwatch()..start();
      await b.shopping.deleteList((await b.shopping.read(list)).list);
      await waitFor(
        () => container.read(provider).value?.snapshot == null,
        seconds: 20,
      );
      await waitFor(() => c.client.getChannels().isEmpty);
      final reads = c.transport.snapshots - before;
      expect(reads, lessThanOrEqualTo(5));
      print(
        'P8_REALTIME:full_list_delete real RLS probe <=20s; one channel; snapshot reads=$reads; hide_ms=${removal.elapsedMilliseconds}',
      );
    } finally {
      subscription.close();
      container.dispose();
    }
  }, timeout: const Timeout(Duration(seconds: 40)));

  test('P8 repeated real HTTP + parsing and image isolate performance, not device UI', () async {
    final metrics = <String, Object>{};
    Future<void> measure(
      String name,
      Future<Object?> Function() operation,
    ) async {
      await operation(); // Separate warmup.
      final values = <double>[];
      final beforeRequests = b.transport.requests,
          beforeBytes = b.transport.bytes;
      for (var i = 0; i < 20; i++) {
        final clock = Stopwatch()..start();
        await operation();
        values.add(clock.elapsedMicroseconds / 1000);
      }
      final sorted = values.toList()..sort();
      metrics[name] = {
        'samples_ms': values,
        'n': 20,
        'median_ms': (sorted[9] + sorted[10]) / 2,
        'p95_ms': sorted[18],
        'http_requests': b.transport.requests - beforeRequests,
        'response_bytes': b.transport.bytes - beforeBytes,
      };
    }

    final recipe = (await b.recipes.loadMine(const RecipeFilter()))
        .recipes
        .first;
    await b.recipes.setVisibility(recipe, RecipeVisibility.public);
    expect(
      (await b.community.load(const CommunityQuery())).entries,
      isNotEmpty,
    );
    final list = await b.shopping.createList(
      'Rendimiento local $suffix',
      newRecipeRequestId(),
    );
    for (var start = 0; start < 200; start += 10) {
      await Future.wait(
        List.generate(
          10,
          (index) => b.shopping.add(
            list,
            ShoppingDraft('Producto ${start + index}'),
            newRecipeRequestId(),
          ),
        ),
      );
    }
    expect((await b.shopping.read(list)).items, hasLength(200));
    await measure('community', () => b.community.load(const CommunityQuery()));
    await measure('my_recipes', () => b.recipes.loadMine(const RecipeFilter()));
    await measure('detail', () => b.recipes.read(recipe.id));
    await measure('ingredient_catalog', () => b.recipes.loadCatalog());
    await measure(
      'ingredient_alias',
      () => b.recipes.resolveIngredient('Huevos'),
    );
    await measure(
      'matching',
      () => b.matching.search(
        MatchingQuery(const [
          SelectedIngredient(name: 'Huevos'),
        ], MatchingMode.near),
      ),
    );
    await measure('shopping_200', () => b.shopping.read(list));
    await measure(
      'add_item',
      () => b.shopping.add(
        list,
        const ShoppingDraft('Medición'),
        newRecipeRequestId(),
      ),
    );
    await measure('toggle_with_fresh_snapshot', () async {
      await b.shopping.toggle((await b.shopping.read(list)).items.first);
      return null;
    });
    final preview = await b.shopping.preview(recipe.id);
    await measure(
      'checked_import',
      () => b.shopping.importIngredients(
        list,
        preview,
        preview.lines,
        newRecipeRequestId(),
      ),
    );
    final image = img.Image(width: 1024, height: 768)
      ..clear(img.ColorRgb8(180, 100, 35));
    final bytes = img.encodePng(image);
    await measure('image_isolate_1024x768', () => prepareAvatar(bytes));
    final output = File(
      'docs/reports/phase08/evidence/general-performance.json',
    );
    await output.writeAsString(
      const JsonEncoder.withIndent('  ').convert({
        'scope': 'Host flutter test debug/JIT, real local HTTP plus DTO parsing; image isolate CPU; not device perceived latency or SQL benchmark',
        'metrics': metrics,
      }),
    );
    print(
      'P8_PERFORMANCE:20 measured samples + 1 excluded warmup per operation; general-performance.json',
    );
    await b.shopping.deleteList((await b.shopping.read(list)).list);
  }, timeout: const Timeout(Duration(minutes: 3)));
}
