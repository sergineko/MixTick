// Isolated GoTrue/PostgREST/Realtime sessions. Only the named transport-loss
// and delayed-response cases are hybrid; permission cases use unmodified I/O.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mixtick/core/network/bounded_http_client.dart';
import 'package:mixtick/features/recipes/data/supabase_recipe_repository.dart';
import 'package:mixtick/features/recipes/domain/recipe.dart';
import 'package:mixtick/features/shopping/data/supabase_shopping_repository.dart';
import 'package:mixtick/features/shopping/domain/shopping.dart';
import 'package:mixtick/features/cook_today/data/supabase_matching_repository.dart';
import 'package:mixtick/features/cook_today/domain/matching.dart';

import 'recipes_local.dart' show RecipeTestPkceStorage;

const endpoint = String.fromEnvironment('SUPABASE_URL'),
    publicKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');

class ShoppingTransport extends http.BaseClient {
  final delegate = BoundedHttpClient();
  bool loseItem = false, loseImport = false;
  Completer<void>? hold, observed;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final response = await delegate.send(request);
    if (request.url.path.endsWith('/add_shopping_item_once') && loseItem ||
        request.url.path.endsWith('/import_recipe_checked') && loseImport) {
      loseItem = false;
      loseImport = false;
      await response.stream.drain<void>();
      throw http.ClientException('Controlled response loss after real commit');
    }
    if (request.url.path.endsWith('/shopping_list_snapshot') && hold != null) {
      observed?.complete();
      await hold!.future;
    }
    return response;
  }

  @override
  void close() => delegate.close();
}

class ShoppingActor {
  ShoppingActor(this.letter, this.suffix) {
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
  final transport = ShoppingTransport();
  late final SupabaseClient client;
  late final repo = SupabaseShoppingRepository(client),
      recipes = SupabaseRecipeRepository(client);
  String get email => 'mixtick-p7-$suffix-$letter@example.test';
  String get username => 'p7_${suffix}_$letter';
  late final password = 'P7-${newRecipeRequestId()}!';
  String? id;
}

void main() {
  final suffix = newRecipeRequestId().replaceAll('-', '').substring(0, 10);
  final actors = <ShoppingActor>[];
  late ShoppingActor a, b, c;
  late String list, other;
  late Recipe recipe, published;
  Future<void> manifest() =>
      File('.tooling/phase07-fixtures.json').writeAsString(
        jsonEncode({
          'users': [
            for (final user in actors)
              if (user.id != null) {'id': user.id, 'email': user.email},
          ],
          'photos': [],
        }),
      );
  Matcher failure(ShoppingFailureCode code) =>
      throwsA(isA<ShoppingFailure>().having((e) => e.code, 'code', code));
  Future<ShoppingSnapshot> fresh([ShoppingActor? actor]) =>
      (actor ?? a).repo.read(list);
  Future<ShoppingInvitation> invite(ShoppingActor user) async {
    await a.repo.invite(list, user.username);
    return (await user.repo.overview()).invitations.singleWhere(
      (i) => i.listId == list,
    );
  }

  Future<void> waitFor(bool Function() predicate) async {
    final deadline = DateTime.now().add(const Duration(seconds: 15));
    while (!predicate()) {
      if (DateTime.now().isAfter(deadline)) {
        throw TimeoutException('Real WebSocket condition not observed');
      }
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
  }

  setUpAll(() async {
    if (endpoint != 'http://127.0.0.1:54321' || publicKey.isEmpty) {
      throw StateError('Only isolated local endpoint permitted');
    }
    a = ShoppingActor('a', suffix);
    b = ShoppingActor('b', suffix);
    c = ShoppingActor('c', suffix);
    actors.addAll([a, b, c]);
    for (final user in actors) {
      final response = await user.client.auth.signUp(
        email: user.email,
        password: user.password,
      );
      user.id = response.user!.id;
      await manifest();
      await user.client.from('profiles').insert({
        'username': user.username,
        'display_name': 'Compra ${user.letter.toUpperCase()}',
      });
    }
    list = await a.repo.createList('Compartida $suffix', newRecipeRequestId());
    other = await b.repo.createList('Propia B $suffix', newRecipeRequestId());
    Future<Recipe> create(String title) async => (await a.recipes.read(
      await a.recipes.save(
        RecipeDraft(
          title: '$title $suffix',
          category: 'Compra controlada',
          servings: 2.5,
          ingredients: [
            const RecipeIngredient(
              ingredientId: '10000000-0000-4000-8000-000000000004',
              name: 'Huevo',
              quantity: 1.25,
              unit: 'ud',
            ),
            const RecipeIngredient(
              customName: 'Miso blanco',
              name: 'Miso blanco',
              quantity: 2.5,
              unit: 'g',
            ),
            const RecipeIngredient(
              ingredientId: '10000000-0000-4000-8000-000000000008',
              name: 'Sal',
              quantity: 0.125,
              unit: 'g',
              optional: true,
            ),
          ],
          steps: ['Paso controlado'],
        ),
        requestId: newRecipeRequestId(),
      ),
    ))!;
    recipe = await create('Privada');
    published = await create('Pública');
    await a.recipes.setVisibility(published, RecipeVisibility.public);
    published = (await a.recipes.read(published.id))!;
  });
  tearDownAll(() async {
    await manifest();
    for (final user in actors) {
      await user.client.dispose();
      user.transport.close();
    }
  });
  test('L01-03 lists persist, owner rename, version conflict, delete confirmed payload', () async {
    final request = newRecipeRequestId();
    final id = await a.repo.createList('Temporal', request);
    expect(await a.repo.createList('Temporal', request), id);
    final old = (await a.repo.read(id)).list;
    await a.repo.rename(old, 'Renombrada');
    expect((await a.repo.read(id)).list.title, 'Renombrada');
    await expectLater(
      a.repo.rename(old, 'Obsoleta'),
      failure(ShoppingFailureCode.conflict),
    );
    await expectLater(
      a.repo.deleteList(old),
      failure(ShoppingFailureCode.conflict),
    );
    await a.repo.deleteList((await a.repo.read(id)).list);
    await expectLater(a.repo.read(id), failure(ShoppingFailureCode.forbidden));
    await expectLater(
      a.repo.createList('Temporal', request),
      failure(ShoppingFailureCode.conflict),
    );
  });
  test('L04-10 free household item, decimals, edits, toggle, delete and request tombstone', () async {
    final request = newRecipeRequestId(),
        id = await a.repo.add(
          list,
          const ShoppingDraft('Jabón', quantity: 0.125, unit: 'l'),
          request,
        );
    expect(
      await a.repo.add(
        list,
        const ShoppingDraft('Jabón', quantity: 0.125, unit: 'l'),
        request,
      ),
      id,
    );
    var item = (await fresh()).items.singleWhere((i) => i.id == id);
    expect(item.ingredientId, isNull);
    expect(item.quantity, 0.125);
    await a.repo.edit(
      item,
      const ShoppingDraft('Jabón suave', quantity: 2, unit: 'ud'),
    );
    item = (await fresh()).items.singleWhere((i) => i.id == id);
    await a.repo.toggle(item);
    item = (await fresh()).items.singleWhere((i) => i.id == id);
    expect(item.purchased, isTrue);
    expect(item.name, 'Jabón suave');
    await a.repo.toggle(item);
    item = (await fresh()).items.singleWhere((i) => i.id == id);
    expect(item.purchased, isFalse);
    await a.repo.remove(item);
    expect((await fresh()).items.where((i) => i.id == id), isEmpty);
    await expectLater(
      a.repo.add(
        list,
        const ShoppingDraft('Jabón', quantity: 0.125, unit: 'l'),
        request,
      ),
      failure(ShoppingFailureCode.conflict),
    );
  });
  test(
    'S01-03 no accepted membership: C/B cannot read, write or self grant',
    () async {
      for (final user in [b, c]) {
        await expectLater(
          user.repo.read(list),
          failure(ShoppingFailureCode.forbidden),
        );
        expect(
          await user.client.from('shopping_items').select().eq('list_id', list),
          isEmpty,
        );
        await expectLater(
          user.repo.add(
            list,
            const ShoppingDraft('Ajeno'),
            newRecipeRequestId(),
          ),
          failure(ShoppingFailureCode.forbidden),
        );
        await expectLater(
          user.client.from('shopping_list_members').insert({
            'list_id': list,
            'user_id': user.id,
          }),
          throwsA(isA<PostgrestException>()),
        );
        expect(
          await user.client
              .from('shopping_lists')
              .delete()
              .eq('id', list)
              .select(),
          isEmpty,
        );
      }
    },
  );
  test('L11-15 explicit pending, wrong recipient, self/missing/duplicate reject and acceptance atomic', () async {
    final inv = await invite(b);
    expect(inv.title, 'Compartida $suffix');
    expect(inv.username, a.username);
    await expectLater(
      b.repo.read(list),
      failure(ShoppingFailureCode.forbidden),
    );
    await expectLater(
      a.repo.respond(inv, true),
      failure(ShoppingFailureCode.forbidden),
    );
    await expectLater(
      c.repo.respond(inv, true),
      failure(ShoppingFailureCode.forbidden),
    );
    await expectLater(
      a.repo.invite(list, b.username),
      failure(ShoppingFailureCode.conflict),
    );
    await expectLater(
      a.repo.invite(list, a.username),
      failure(ShoppingFailureCode.invalid),
    );
    await expectLater(
      a.repo.invite(list, 'missing_$suffix'),
      failure(ShoppingFailureCode.invalid),
    );
    await Future.wait(List.generate(4, (_) => b.repo.respond(inv, true)));
    expect((await fresh()).members.where((m) => m.id == b.id).length, 1);
    expect((await fresh(b)).list.id, list);
    expect(
      (await b.repo.overview()).lists.map((l) => l.id),
      containsAll([list, other]),
    );
  });
  test('L16 rejected invitation cannot reopen or grant C access', () async {
    final inv = await invite(c);
    await c.repo.respond(inv, false);
    await c.repo.respond(inv, false);
    await expectLater(
      c.repo.respond(inv, true),
      failure(ShoppingFailureCode.invalid),
    );
    await expectLater(
      c.repo.read(list),
      failure(ShoppingFailureCode.forbidden),
    );
  });
  test(
    'L17 member edits products, cannot invite, rename, delete or revoke',
    () async {
      final id = await b.repo.add(
        list,
        const ShoppingDraft('Pan'),
        newRecipeRequestId(),
      );
      var item = (await fresh()).items.singleWhere((i) => i.id == id);
      await b.repo.edit(
        item,
        const ShoppingDraft('Pan integral', quantity: 1, unit: 'ud'),
      );
      item = (await fresh()).items.singleWhere((i) => i.id == id);
      expect(item.name, 'Pan integral');
      await expectLater(
        b.repo.invite(list, c.username),
        failure(ShoppingFailureCode.forbidden),
      );
      await expectLater(
        b.repo.revoke(list, a.id!),
        failure(ShoppingFailureCode.forbidden),
      );
      expect(
        await b.client
            .from('shopping_lists')
            .update({'title': 'Suplantada'})
            .eq('id', list)
            .select(),
        isEmpty,
      );
      expect(
        await b.client.from('shopping_lists').delete().eq('id', list).select(),
        isEmpty,
      );
      await expectLater(
        b.client.rpc(
          'update_shopping_item',
          params: {
            'p_item_id': id,
            'p_expected_version': item.version,
            'p_changes': {'list_id': other},
          },
        ),
        throwsA(isA<PostgrestException>()),
      );
    },
  );
  test('L23-24 concurrent edits: exactly one winner, other gets PT409, no hidden overwrite', () async {
    final id = await a.repo.add(
      list,
      const ShoppingDraft('Concurrente'),
      newRecipeRequestId(),
    );
    final item = (await fresh()).items.singleWhere((i) => i.id == id);
    final results = await Future.wait(
      [a, b].map(
        (u) => u.repo
            .edit(
              item,
              ShoppingDraft('Cambio ${u.letter}', quantity: u == a ? 1 : 2),
            )
            .then<Object>((_) => 'PASS')
            .catchError((Object e) => e),
      ),
    );
    expect(results.where((r) => r == 'PASS').length, 1);
    expect(
      results.whereType<ShoppingFailure>().single.code,
      ShoppingFailureCode.conflict,
    );
    expect(
      (await fresh()).items.singleWhere((i) => i.id == id).version,
      item.version + 1,
    );
  });
  test('L30-35 private import: original quantities, retries, bought state, new deliberate request, tombstones', () async {
    final preview = await a.repo.preview(recipe.id),
        request = newRecipeRequestId();
    final ids = await a.repo.importIngredients(
      list,
      preview,
      preview.lines,
      request,
    );
    expect(ids.length, 3);
    await expectLater(
      a.repo.importIngredients(list, preview, [preview.lines.first], request),
      failure(ShoppingFailureCode.conflict),
    );
    expect(
      await a.repo.importIngredients(
        list,
        preview,
        preview.lines.reversed.toList(),
        request,
      ),
      ids,
    );
    var snapshot = await fresh(b);
    final first = snapshot.items.singleWhere((i) => i.id == ids.first);
    expect(first.quantity, 1.25);
    expect(first.unit, 'ud');
    await b.repo.toggle(first);
    await a.repo.importIngredients(list, preview, preview.lines, request);
    expect(
      (await fresh()).items.singleWhere((i) => i.id == ids.first).purchased,
      isTrue,
    );
    await a.repo.remove(
      (await fresh()).items.singleWhere((i) => i.id == ids.last),
    );
    expect(
      await a.repo.importIngredients(list, preview, preview.lines, request),
      ids,
    );
    expect((await fresh()).items.where((i) => i.id == ids.last), isEmpty);
    final again = await a.repo.importIngredients(
      list,
      preview,
      preview.lines,
      newRecipeRequestId(),
    );
    expect(again.toSet().intersection(ids.toSet()), isEmpty);
  });
  test('L36-40 origin is private, C cannot import; transaction rejects bad ID/ordinal, stale recipe, optional missing', () async {
    await expectLater(
      b.repo.preview(recipe.id),
      failure(ShoppingFailureCode.forbidden),
    );
    final preview = await a.repo.preview(recipe.id);
    await expectLater(
      b.repo.importIngredients(
        list,
        preview,
        preview.lines,
        newRecipeRequestId(),
      ),
      failure(ShoppingFailureCode.forbidden),
    );
    await expectLater(
      c.repo.importIngredients(
        list,
        await c.repo.preview(published.id),
        (await c.repo.preview(published.id)).lines,
        newRecipeRequestId(),
      ),
      failure(ShoppingFailureCode.forbidden),
    );
    final before = (await fresh()).items.length;
    final params = {
      'p_list_id': list,
      'p_recipe_id': recipe.id,
      'p_expected_version': preview.version,
      'p_request_id': newRecipeRequestId(),
      'p_line_ids': [preview.lines.first.lineId, newRecipeRequestId()],
      'p_ordinals': [preview.lines.first.ordinal, 99],
    };
    await expectLater(
      a.client.rpc('import_recipe_checked', params: params),
      throwsA(isA<PostgrestException>()),
    );
    expect((await fresh()).items.length, before);
    await expectLater(
      a.repo.importIngredients(
        list,
        preview,
        [preview.lines.last],
        newRecipeRequestId(),
        missingOnly: true,
      ),
      failure(ShoppingFailureCode.conflict),
    );
    final raw = await b.client
        .from('shopping_items')
        .select()
        .eq('list_id', list);
    for (final row in raw) {
      expect(row.keys, isNot(contains('recipe_id')));
      expect(jsonEncode(row), isNot(contains(recipe.id)));
      expect(jsonEncode(row), isNot(contains(recipe.title)));
    }
    await a.recipes.setVisibility(recipe, RecipeVisibility.public);
    await expectLater(
      a.repo.importIngredients(
        list,
        preview,
        preview.lines,
        newRecipeRequestId(),
      ),
      failure(ShoppingFailureCode.conflict),
    );
    recipe = (await a.recipes.read(recipe.id))!;
    await a.recipes.setVisibility(recipe, RecipeVisibility.private);
    recipe = (await a.recipes.read(recipe.id))!;
  });
  test('L31-33 actual matching transfer imports only mandatory missing and preserves free quantity/unit', () async {
    final matches = await SupabaseMatchingRepository(b.client).search(
      MatchingQuery([
        const SelectedIngredient(
          id: '10000000-0000-4000-8000-000000000004',
          name: 'Huevo',
        ),
      ], MatchingMode.near),
    );
    final match = matches.matches.singleWhere(
      (m) => m.recipe.id == published.id,
    );
    expect(match.missing, 1);
    expect(match.transfer.lines.single.ingredient.customName, 'Miso blanco');
    final preview = await b.repo.preview(published.id);
    expect(preview.accepts(match.transfer), isTrue);
    final ids = await b.repo.importIngredients(
      other,
      preview,
      match.transfer.lines,
      newRecipeRequestId(),
      missingOnly: true,
    );
    final item = (await b.repo.read(other)).items
        .singleWhere((i) => i.id == ids.single);
    expect(item.name, 'Miso blanco');
    expect(item.quantity, 2.5);
    expect(item.unit, 'g');
    expect(item.ingredientId, isNull);
    final old = match.transfer;
    await a.recipes.setVisibility(published, RecipeVisibility.private);
    await expectLater(
      b.repo.preview(published.id),
      failure(ShoppingFailureCode.forbidden),
    );
    published = (await a.recipes.read(published.id))!;
    await a.recipes.setVisibility(published, RecipeVisibility.public);
    published = (await a.recipes.read(published.id))!;
    expect((await b.repo.preview(published.id)).accepts(old), isFalse);
  });
  test('L34/48 HYBRID lost real committed create/import responses reuse UUID without duplicating', () async {
    final request = newRecipeRequestId();
    a.transport.loseItem = true;
    await expectLater(
      a.repo.add(list, const ShoppingDraft('Respuesta perdida'), request),
      failure(ShoppingFailureCode.network),
    );
    final id = await a.repo.add(
      list,
      const ShoppingDraft('Respuesta perdida'),
      request,
    );
    expect((await fresh()).items.where((i) => i.id == id).length, 1);
    final preview = await a.repo.preview(recipe.id),
        operation = newRecipeRequestId(),
        before = (await fresh()).items.length;
    a.transport.loseImport = true;
    await expectLater(
      a.repo.importIngredients(list, preview, preview.lines, operation),
      failure(ShoppingFailureCode.network),
    );
    await a.repo.importIngredients(list, preview, preview.lines, operation);
    expect((await fresh()).items.length, before + preview.lines.length);
  });
  test('L21-22/25/29 real independent A/B WebSockets: add, toggle, quantity, deletion signal and reconnect', () async {
    var connectedA = false, connectedB = false, eventsA = 0, eventsB = 0;
    final subA = a.repo.watch(list).listen((s) {
      if (s == ShoppingSignal.connected) connectedA = true;
      if (s == ShoppingSignal.changed) eventsA++;
    });
    var subB = b.repo.watch(list).listen((s) {
      if (s == ShoppingSignal.connected) connectedB = true;
      if (s == ShoppingSignal.changed) eventsB++;
    });
    try {
      await waitFor(() => connectedA && connectedB);
      final countB = eventsB,
          id = await a.repo.add(
            list,
            const ShoppingDraft('Realtime'),
            newRecipeRequestId(),
          );
      await waitFor(() => eventsB > countB);
      expect((await fresh(b)).items.any((i) => i.id == id), isTrue);
      final countA = eventsA;
      await b.repo.toggle(
        (await fresh(b)).items.singleWhere((i) => i.id == id),
      );
      await waitFor(() => eventsA > countA);
      expect(
        (await fresh()).items.singleWhere((i) => i.id == id).purchased,
        isTrue,
      );
      final changeB = eventsB;
      await a.repo.edit(
        (await fresh()).items.singleWhere((i) => i.id == id),
        const ShoppingDraft('Realtime', quantity: 3.5, unit: 'kg'),
      );
      await waitFor(() => eventsB > changeB);
      expect(
        (await fresh(b)).items.singleWhere((i) => i.id == id).quantity,
        3.5,
      );
      final deletedB = eventsB;
      await a.repo.remove((await fresh()).items.singleWhere((i) => i.id == id));
      await waitFor(() => eventsB > deletedB);
      expect((await fresh(b)).items.where((i) => i.id == id), isEmpty);
      await subB.cancel();
      await b.client.realtime.disconnect();
      connectedB = false;
      final offline = await a.repo.add(
        list,
        const ShoppingDraft('Durante desconexión'),
        newRecipeRequestId(),
      );
      subB = b.repo.watch(list).listen((s) {
        if (s == ShoppingSignal.connected) connectedB = true;
        if (s == ShoppingSignal.changed) eventsB++;
      });
      await waitFor(() => connectedB);
      expect((await fresh(b)).items.any((i) => i.id == offline), isTrue);
      debugPrint(
        'PASS Realtime: independent sockets A/B delivered authorized changes; reconnect reread reconciled deletion/offline insertion',
      );
    } finally {
      await subA.cancel();
      await subB.cancel();
    }
    expect(a.client.getChannels(), isEmpty);
    expect(b.client.getChannels(), isEmpty);
  }, timeout: const Timeout(Duration(seconds: 80)));
  test('L28 unauthorized C and anon raw WebSocket attempts receive no product events', () async {
    final anon = SupabaseClient(
      endpoint,
      publicKey,
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
    var events = 0;
    final channels = <RealtimeChannel>[];
    try {
      for (final client in [c.client, anon]) {
        final channel = client
            .channel('negative-${newRecipeRequestId()}')
            .onPostgresChanges(
              event: PostgresChangeEvent.insert,
              schema: 'public',
              table: 'shopping_items',
              filter: PostgresChangeFilter(
                type: PostgresChangeFilterType.eq,
                column: 'list_id',
                value: list,
              ),
              callback: (_) => events++,
            )
            .subscribe();
        channels.add(channel);
      }
      await Future<void>.delayed(const Duration(seconds: 2));
      await a.repo.add(
        list,
        const ShoppingDraft('No revelar a C'),
        newRecipeRequestId(),
      );
      await Future<void>.delayed(const Duration(seconds: 3));
      expect(events, 0);
      expect(
        await c.client.from('shopping_items').select().eq('list_id', list),
        isEmpty,
      );
    } finally {
      await c.client.removeChannel(channels.first);
      await anon.dispose();
    }
  });
  test('L18-20/28 revoke, old acceptance, block and leave cannot bypass membership', () async {
    final prior = await b.client
        .from('shopping_list_invitations')
        .select()
        .eq('list_id', list)
        .eq('invitee_id', b.id!)
        .eq('status', 'accepted');
    final old = ShoppingInvitation.fromJson(prior.single);
    await a.repo.revoke(list, b.id!);
    await expectLater(
      b.repo.read(list),
      failure(ShoppingFailureCode.forbidden),
    );
    await expectLater(
      b.repo.respond(old, true),
      failure(ShoppingFailureCode.invalid),
    );
    await expectLater(
      b.repo.add(list, const ShoppingDraft('Revocado'), newRecipeRequestId()),
      failure(ShoppingFailureCode.forbidden),
    );
    final errors = <Object>[];
    final sub = b.repo.watch(list).listen((_) {}, onError: errors.add);
    await waitFor(() => errors.isNotEmpty);
    expect(b.client.getChannels(), isEmpty);
    await sub.cancel();
    final inv = await invite(b);
    await b.repo.respond(inv, true);
    await b.repo.leave(list);
    await expectLater(
      b.repo.respond(inv, true),
      failure(ShoppingFailureCode.invalid),
    );
    await b.client.from('user_blocks').insert({'blocked_id': a.id});
    await expectLater(
      a.repo.invite(list, b.username),
      failure(ShoppingFailureCode.invalid),
    );
    await b.client.from('user_blocks').delete().eq('blocked_id', a.id!);
  });
  test('L10 persistence across a real fresh client session; basic 200-item snapshot measurement', () async {
    final prior = await fresh();
    final restarted = SupabaseClient(
      endpoint,
      publicKey,
      authOptions: AuthClientOptions(
        autoRefreshToken: false,
        pkceAsyncStorage: RecipeTestPkceStorage(),
      ),
    );
    try {
      await restarted.auth.signInWithPassword(
        email: a.email,
        password: a.password,
      );
      final actual = await SupabaseShoppingRepository(restarted).read(list);
      expect(
        actual.items.map((i) => i.id).toSet(),
        prior.items.map((i) => i.id).toSet(),
      );
      expect(
        actual.items.where((i) => i.purchased).map((i) => i.id).toSet(),
        prior.items.where((i) => i.purchased).map((i) => i.id).toSet(),
      );
    } finally {
      await restarted.dispose();
    }
    final volume = await a.repo.createList(
      'Volumen controlado',
      newRecipeRequestId(),
    );
    for (var start = 0; start < 200; start += 10) {
      await Future.wait(
        List.generate(
          10,
          (offset) => a.repo.add(
            volume,
            ShoppingDraft(
              'Producto ${start + offset}',
              quantity: 0.125,
              unit: 'ud',
            ),
            newRecipeRequestId(),
          ),
        ),
      );
    }
    final stopwatch = Stopwatch()..start();
    final snapshot = await a.repo.read(volume);
    stopwatch.stop();
    expect(snapshot.items.length, 200);
    final addWatch = Stopwatch()..start();
    final id = await a.repo.add(
      volume,
      const ShoppingDraft('Medición'),
      newRecipeRequestId(),
    );
    addWatch.stop();
    final item = (await a.repo.read(volume)).items
        .singleWhere((i) => i.id == id);
    final toggleWatch = Stopwatch()..start();
    await a.repo.toggle(item);
    toggleWatch.stop();
    final preview = await a.repo.preview(recipe.id);
    final importWatch = Stopwatch()..start();
    await a.repo.importIngredients(
      volume,
      preview,
      preview.lines,
      newRecipeRequestId(),
    );
    importWatch.stop();
    debugPrint(
      'P7_PERFORMANCE:${jsonEncode({'items': 200, 'snapshot_ms': stopwatch.elapsedMilliseconds, 'add_ms': addWatch.elapsedMilliseconds, 'toggle_ms': toggleWatch.elapsedMilliseconds, 'import_ms': importWatch.elapsedMilliseconds, 'import_lines': preview.lines.length, 'scope': 'one local authenticated HTTP sample, includes DTO parsing; not device FPS or production benchmark'})}',
    );
    await a.repo.deleteList((await a.repo.read(volume)).list);
  });
  test('L27/45 HYBRID response held across real identity switch cannot expose old list', () async {
    final inv = await invite(b);
    await b.repo.respond(inv, true);
    final gate = Completer<void>(), observed = Completer<void>();
    b.transport.hold = gate;
    b.transport.observed = observed;
    final pending = b.repo.read(list);
    final assertion = expectLater(
      pending,
      failure(ShoppingFailureCode.forbidden),
    );
    await observed.future;
    await b.client.auth.signOut();
    await b.client.auth.signInWithPassword(
      email: c.email,
      password: c.password,
    );
    b.transport.hold = null;
    gate.complete();
    await assertion;
    await b.client.auth.signOut();
    await b.client.auth.signInWithPassword(
      email: b.email,
      password: b.password,
    );
    var connected = false;
    final sub = b.repo.watch(list).listen((s) {
      if (s == ShoppingSignal.connected) connected = true;
    });
    await waitFor(() => connected);
    await b.client.auth.signOut();
    await waitFor(() => b.client.getChannels().isEmpty);
    await sub.cancel();
    await expectLater(
      b.repo.read(list),
      failure(ShoppingFailureCode.forbidden),
    );
  });
}
