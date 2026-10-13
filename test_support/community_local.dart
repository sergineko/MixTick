// Explicit local Auth/API/Storage A/B/C suite. No service_role or RLS mocks.
import 'dart:convert';
import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:flutter_test/flutter_test.dart';
import 'package:mixtick/core/network/bounded_http_client.dart';
import 'package:mixtick/features/community/data/supabase_community_repository.dart';
import 'package:mixtick/features/community/domain/community.dart';
import 'package:mixtick/features/recipes/domain/recipe.dart';
import 'package:mixtick/features/recipes/domain/recipe_repository.dart';
import 'package:mixtick/features/recipes/data/supabase_recipe_repository.dart';
import 'package:mixtick/features/profile/data/supabase_profile_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'recipes_local.dart' show RecipeTestPkceStorage, richDraft;

const endpoint = String.fromEnvironment('SUPABASE_URL');
const publicKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');

class ControlledCommunityTransport extends http.BaseClient {
  final delegate = BoundedHttpClient();
  bool failNext = false;
  Completer<void>? holdRecipeRead, readObserved;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (failNext && request.url.path == '/rest/v1/rpc/community_page') {
      failNext = false;
      throw http.ClientException('Controlled one-shot transport loss');
    }
    final response = await delegate.send(request);
    if (holdRecipeRead != null &&
        request.method == 'GET' &&
        request.url.path == '/rest/v1/recipes') {
      readObserved?.complete();
      await holdRecipeRead!.future;
    }
    return response;
  }

  @override
  void close() => delegate.close();
}

class SocialActor {
  SocialActor(this.letter, this.suffix)
    : transport = ControlledCommunityTransport() {
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
  final ControlledCommunityTransport transport;
  late final SupabaseClient client;
  String get email => 'mixtick-p5-$suffix-$letter@example.test';
  String get username => 'p5_${suffix}_$letter';
  late final password = 'P5-fixture-${newRecipeRequestId()}!';
  String? id;
  late final recipes = SupabaseRecipeRepository(client);
  late final social = SupabaseCommunityRepository(client);
}

Matcher denied = throwsA(
  isA<CommunityFailure>().having(
    (e) => e.code,
    'code',
    CommunityFailureCode.forbidden,
  ),
);
void main() {
  final suffix = newRecipeRequestId().replaceAll('-', '').substring(0, 10);
  late SocialActor a, b, c;
  final actors = <SocialActor>[];
  final photos = <String>{}, avatars = <String>{}, publicIds = <String>{};
  late Recipe base, privateRecipe;
  late String commentId, commentRequest, photo;
  final image = img.encodePng(
    img.Image(width: 64, height: 64)..clear(img.ColorRgb8(184, 72, 44)),
  );
  Future<Recipe> fresh(SocialActor actor, String id) async =>
      (await actor.recipes.read(id))!;
  Future<void> manifest() async =>
      File('.tooling/phase05-fixtures.json').writeAsString(
        jsonEncode({
          'suffix': suffix,
          'users': [
            for (final actor in actors)
              if (actor.id != null) {'id': actor.id, 'email': actor.email},
          ],
          'photos': photos.toList(),
          'avatars': avatars.toList(),
        }),
      );
  Future<void> publish(Recipe recipe) async {
    await a.recipes.setVisibility(recipe, RecipeVisibility.public);
    publicIds.add(recipe.id);
  }

  setUpAll(() async {
    if (endpoint != 'http://127.0.0.1:54321' || publicKey.isEmpty) {
      throw StateError('Only isolated local endpoint allowed');
    }
    a = SocialActor('a', suffix);
    b = SocialActor('b', suffix);
    c = SocialActor('c', suffix);
    actors.addAll([a, b, c]);
    for (final actor in actors) {
      final auth = await actor.client.auth.signUp(
        email: actor.email,
        password: actor.password,
      );
      expect(auth.session, isNotNull);
      actor.id = auth.user!.id;
      await manifest();
      await actor.client.from('profiles').insert({
        'username': actor.username,
        'display_name': 'Prueba social ${actor.letter.toUpperCase()}',
      });
    }
  });
  tearDownAll(() async {
    await manifest();
    for (final actor in actors) {
      await actor.client.dispose();
    }
  });
  test(
    'C02 private recipes excluded from feed, categories and ingredient search',
    () async {
      base = await fresh(
        a,
        await a.recipes.save(
          richDraft('Sopa pública $suffix'),
          requestId: newRecipeRequestId(),
        ),
      );
      privateRecipe = await fresh(
        a,
        await a.recipes.save(
          RecipeDraft(
            title: 'Secreto $suffix',
            category: 'Categoría privada $suffix',
            servings: 1,
            ingredients: const [
              RecipeIngredient(
                customName: 'Ingrediente confidencial',
                name: 'Ingrediente confidencial',
              ),
            ],
            steps: ['Paso confidencial'],
          ),
          requestId: newRecipeRequestId(),
        ),
      );
      photo = await a.recipes.uploadPhoto(base, image, PhotoCancellation());
      photos.add(photo);
      await manifest();
      await a.recipes.setPhoto(base, photo);
      base = await fresh(a, base.id);
      final profiles = SupabaseProfileRepository(a.client);
      final own = (await profiles.loadOwn())!;
      final avatar = await profiles.uploadAvatar(image);
      avatars.add(avatar);
      await manifest();
      await profiles.save(
        username: own.username,
        displayName: own.displayName,
        previous: own,
        avatarPath: avatar,
      );
      for (final actor in [a, b, c]) {
        expect(
          (await actor.social.load(const CommunityQuery())).entries,
          isEmpty,
        );
        expect(await actor.social.categories(), isEmpty);
        expect(
          (await actor.social.load(
            const CommunityQuery(search: 'Ingrediente confidencial'),
          )).entries,
          isEmpty,
        );
      }
    },
  );
  test('C01 publishing appears in chronological public projection with safe author and image', () async {
    await publish(base);
    base = await fresh(a, base.id);
    final page = await b.social.load(const CommunityQuery());
    expect(page.entries.single.recipe.id, base.id);
    expect(page.entries.single.author.username, a.username);
    expect(page.entries.single.recipe.photoPath, photo);
    expect(await b.recipes.downloadPhoto(photo), isNotEmpty);
    final row = await b.client.rpc(
      'community_author',
      params: {'p_username': a.username},
    ) as Map<String, dynamic>;
    expect((row['profile'] as Map).keys.toSet(), {
      'username',
      'display_name',
      'avatar_path',
    });
    expect(jsonEncode(row), isNot(contains(a.email)));
  });
  test('C03 title search is accent normalized and treats wildcard syntax literally', () async {
    expect(
      (await b.social.load(CommunityQuery(search: 'SOPA PÚBLICA $suffix')))
          .entries
          .single
          .recipe
          .id,
      base.id,
    );
    expect(
      (await b.social.load(const CommunityQuery(search: '%_'))).entries,
      isEmpty,
    );
  });
  test('C04 exact category filter never reveals private category', () async {
    expect(
      (await b.social.load(const CommunityQuery(category: 'Principal')))
          .entries
          .single
          .recipe
          .id,
      base.id,
    );
    expect(
      (await b.social.load(CommunityQuery(category: privateRecipe.category)))
          .entries,
      isEmpty,
    );
    expect(await b.social.categories(), ['Principal']);
  });
  test('C05 canonical ingredient aliases and exact normalized free text, no invented equivalence', () async {
    for (final query in [
      'Tomate',
      ' tOMÁTES ',
      'Hierba única de prueba',
      'HIERBA UNICA DE PRUEBA',
    ]) {
      expect(
        (await b.social.load(CommunityQuery(search: query)))
            .entries
            .single
            .recipe
            .id,
        base.id,
      );
    }
    for (final query in ['Tomat', 'Hierba', 'Leche', 'aceite']) {
      expect(
        (await b.social.load(CommunityQuery(search: query))).entries,
        isEmpty,
      );
    }
  });
  test(
    'C06 keyset pagination 8+1 with stable publication and UUID, no duplicates',
    () async {
      for (var i = 0; i < 8; i++) {
        final recipe = await fresh(
          a,
          await a.recipes.save(
            richDraft('Página $i $suffix'),
            requestId: newRecipeRequestId(),
          ),
        );
        await publish(recipe);
      }
      final first = await b.social.load(const CommunityQuery());
      expect(first.entries.length, 8);
      expect(first.cursor, isNotNull);
      final second = await b.social.load(
        const CommunityQuery(),
        cursor: first.cursor,
      );
      expect(second.entries.length, 1);
      expect(second.cursor, isNull);
      final all = [...first.entries, ...second.entries];
      expect(all.map((r) => r.recipe.id).toSet(), publicIds);
      for (var i = 1; i < all.length; i++) {
        expect(all[i - 1].publishedAt.isBefore(all[i].publishedAt), false);
      }
      expect((await c.social.load(const CommunityQuery())).entries.length, 8);
    },
  );
  test('C07 public card UUID opens the original typed aggregate', () async {
    final entry = (await b.social.entry(base.id))!;
    final detail = (await b.recipes.read(entry.recipe.id))!;
    expect(detail.title, base.title);
    expect(detail.ingredients.length, 3);
    expect(detail.steps, base.steps);
    expect(detail.authorId, a.id);
  });
  test('C08 like and unlike use authoritative nonnegative counts', () async {
    await b.social.like(base.id, true);
    expect((await b.social.entry(base.id))!.likes, 1);
    expect((await b.social.entry(base.id))!.liked, true);
    await b.social.like(base.id, false);
    await b.social.like(base.id, false);
    expect((await b.social.entry(base.id))!.likes, 0);
  });
  test(
    'C09 concurrent repeated likes cannot duplicate or change another user',
    () async {
      await Future.wait([
        b.social.like(base.id, true),
        b.social.like(base.id, true),
      ]);
      await b.social.like(base.id, true);
      expect((await b.social.entry(base.id))!.likes, 1);
      await c.client
          .from('recipe_likes')
          .delete()
          .eq('recipe_id', base.id)
          .eq('user_id', b.id!);
      expect((await b.social.entry(base.id))!.likes, 1);
      await b.social.like(base.id, false);
    },
  );
  test(
    'C10 real comment, author/date, retry-safe UUID and server count',
    () async {
      commentRequest = newRecipeRequestId();
      await Future.wait([
        b.social.comment(base.id, 'Buen resultado local', commentRequest),
        b.social.comment(base.id, 'Buen resultado local', commentRequest),
      ]);
      final page = await c.social.comments(base.id);
      commentId = page.comments.single.id;
      expect(commentId, isNot(commentRequest));
      expect(page.comments.single.author.username, b.username);
      expect(
        page.comments.single.createdAt.isBefore(
          DateTime.now().add(const Duration(seconds: 10)),
        ),
        true,
      );
      expect((await a.social.entry(base.id))!.comments, 1);
    },
  );
  test(
    'C11 empty, excessive and direct API invalid comments rejected',
    () async {
      for (final value in ['   ', '\n\t', 'x' * 2001]) {
        await expectLater(
          b.social.comment(base.id, value, newRecipeRequestId()),
          throwsA(isA<CommunityFailure>()),
        );
        await expectLater(
          b.client.from('recipe_comments').insert({
            'recipe_id': base.id,
            'content': value,
          }),
          throwsA(isA<PostgrestException>()),
        );
      }
      await expectLater(
        b.social.comment(base.id, 'Alterado', commentRequest),
        throwsA(
          isA<CommunityFailure>().having(
            (e) => e.code,
            'code',
            CommunityFailureCode.conflict,
          ),
        ),
      );
    },
  );
  test(
    'C13 foreign deletion denied by repository and direct API policy',
    () async {
      await expectLater(c.social.deleteComment(commentId), denied);
      expect(
        await c.client
            .from('recipe_comments')
            .delete()
            .eq('id', commentId)
            .select('id'),
        isEmpty,
      );
      expect((await b.social.comments(base.id)).comments.single.id, commentId);
    },
  );
  test('C12 own deletion persists and count returns to zero', () async {
    await b.social.deleteComment(commentId);
    await expectLater(
      b.social.comment(base.id, 'Buen resultado local', commentRequest),
      throwsA(
        isA<CommunityFailure>().having(
          (e) => e.code,
          'code',
          CommunityFailureCode.conflict,
        ),
      ),
    );
    expect((await a.social.comments(base.id)).comments, isEmpty);
    expect((await a.social.entry(base.id))!.comments, 0);
  });
  test('C14 follow/unfollow, duplicate safety and visible counts', () async {
    await Future.wait([
      b.social.follow(a.id!, true),
      b.social.follow(a.id!, true),
    ]);
    expect((await b.social.author(a.username))!.followed, true);
    expect((await b.social.author(a.username))!.followers, 1);
    expect((await b.social.author(b.username))!.following, 1);
    await b.social.follow(a.id!, false);
    await b.social.follow(a.id!, false);
    expect((await b.social.author(a.username))!.followers, 0);
    expect(
      (await b.social.load(CommunityQuery(author: a.username))).entries.length,
      8,
    );
  });
  test('C15 self-follow rejected in domain and direct API', () async {
    await expectLater(
      b.social.follow(b.id!, true),
      throwsA(isA<CommunityFailure>()),
    );
    await expectLater(
      b.client.from('user_follows').insert({'followed_id': b.id}),
      throwsA(isA<PostgrestException>()),
    );
  });
  test(
    'C16 C17 saves are original references and searchable from recetario query',
    () async {
      await b.social.save(base.id, true);
      expect((await b.social.entry(base.id))!.saved, true);
      final page = await b.social.load(
        CommunityQuery(saved: true, search: 'Sopa', category: 'Principal'),
      );
      expect(page.entries.single.recipe.id, base.id);
      expect(page.entries.single.recipe.authorId, a.id);
      expect(
        await b.client.from('recipes').select('id').eq('author_id', b.id!),
        isEmpty,
      );
    },
  );
  test(
    'C19 concurrent repeated saves stay unique and private to saver',
    () async {
      await Future.wait([
        b.social.save(base.id, true),
        b.social.save(base.id, true),
      ]);
      expect(
        (await b.social.load(const CommunityQuery(saved: true))).entries.length,
        1,
      );
      expect(
        (await c.social.load(const CommunityQuery(saved: true))).entries,
        isEmpty,
      );
      expect(
        await c.client.from('recipe_saves').select().eq('user_id', b.id!),
        isEmpty,
      );
    },
  );
  test(
    'C17 real saved search and pagination 8+1 without copies or duplicated IDs',
    () async {
      for (final id in publicIds) {
        await b.social.save(id, true);
      }
      final query = CommunityQuery(
        saved: true,
        search: suffix,
        category: 'Principal',
      );
      final first = await b.social.load(query);
      expect(first.entries.length, 8);
      expect(first.cursor, isNotNull);
      final next = await b.social.load(query, cursor: first.cursor);
      expect(next.entries.length, 1);
      expect(next.cursor, isNull);
      expect(
        [...first.entries, ...next.entries].map((r) => r.recipe.id).toSet(),
        publicIds,
      );
      expect(
        await b.client.from('recipes').select('id').eq('author_id', b.id!),
        isEmpty,
      );
      for (final id in publicIds.where((id) => id != base.id)) {
        await b.social.save(id, false);
      }
    },
  );
  test('C18 remove original saved reference without deleting recipe', () async {
    await b.social.save(base.id, false);
    await b.social.save(base.id, false);
    expect(
      (await b.social.load(const CommunityQuery(saved: true))).entries,
      isEmpty,
    );
    expect(await a.recipes.read(base.id), isNotNull);
  });
  test('C20 C26 privatization removes saved content, counts, search and authenticated photos', () async {
    await b.social.save(base.id, true);
    await b.social.like(base.id, true);
    commentRequest = newRecipeRequestId();
    await b.social.comment(base.id, 'Se oculta con la receta', commentRequest);
    commentId = (await b.social.comments(base.id)).comments.single.id;
    final prior = (await b.social.entry(base.id))!;
    base = await fresh(a, base.id);
    await a.recipes.setVisibility(base, RecipeVisibility.private);
    for (final actor in [b, c]) {
      expect(await actor.social.entry(base.id), isNull);
      expect(await actor.recipes.read(base.id), isNull);
      expect(
        (await actor.social.load(
          CommunityQuery(search: 'Sopa pública $suffix'),
        )).entries,
        isEmpty,
      );
      expect(
        (await actor.social.load(const CommunityQuery(saved: true))).entries,
        isEmpty,
      );
      await expectLater(actor.social.comments(base.id), denied);
      for (final table in [
        'recipe_comments',
        'recipe_likes',
        'recipe_saves',
        'recipe_ingredients',
        'recipe_steps',
      ]) {
        expect(
          await actor.client.from(table).select().eq('recipe_id', base.id),
          isEmpty,
        );
      }
      await expectLater(
        actor.recipes.downloadPhoto(prior.recipe.photoPath!),
        throwsA(isA<RecipeFailure>()),
      );
      await expectLater(
        actor.client.storage.from('recipe-photos').download(photo),
        throwsA(isA<StorageException>()),
      );
      expect(
        await actor.client.rpc(
          'community_page',
          params: {'p_recipe_id': base.id},
        ),
        isEmpty,
      );
    }
    base = await fresh(a, base.id);
    await publish(base);
    base = await fresh(a, base.id);
    expect((await b.social.entry(base.id))!.publishedAt, prior.publishedAt);
  });
  test(
    'C21 private foreign interactions and spoofed user identities rejected',
    () async {
      for (final actor in [b, c]) {
        await expectLater(actor.social.like(privateRecipe.id, true), denied);
        await expectLater(actor.social.save(privateRecipe.id, true), denied);
        await expectLater(
          actor.social.comment(
            privateRecipe.id,
            'No autorizado',
            newRecipeRequestId(),
          ),
          denied,
        );
        for (final table in ['recipe_likes', 'recipe_saves']) {
          await expectLater(
            actor.client.from(table).insert({'recipe_id': privateRecipe.id}),
            throwsA(isA<PostgrestException>()),
          );
        }
        await expectLater(
          actor.client.from('recipe_comments').insert({
            'recipe_id': privateRecipe.id,
            'content': 'No autorizado',
          }),
          throwsA(isA<PostgrestException>()),
        );
        await expectLater(
          actor.client.from('recipe_likes').insert({
            'recipe_id': base.id,
            'user_id': a.id,
          }),
          throwsA(isA<PostgrestException>()),
        );
      }
    },
  );
  test('C22 C23 symmetric block hides author/feed/profile and denies interactions; unblock restores', () async {
    await b.social.follow(a.id!, true);
    await b.social.block(a.id!, true);
    await b.social.block(a.id!, true);
    expect(await b.social.blocked(), [a.id]);
    expect((await b.social.load(const CommunityQuery())).entries, isEmpty);
    expect(await b.social.author(a.username), isNull);
    expect(await a.social.author(b.username), isNull);
    expect(await b.recipes.read(base.id), isNull);
    await expectLater(b.social.follow(a.id!, true), denied);
    await expectLater(b.social.like(base.id, true), denied);
    expect(
      await b.client.from('profiles').select().eq('user_id', a.id!),
      isEmpty,
    );
    await expectLater(
      b.client.storage.from('profile-avatars').download(avatars.single),
      throwsA(isA<StorageException>()),
    );
    expect((await c.social.entry(base.id))!.recipe.id, base.id);
    await b.social.block(a.id!, false);
    await b.social.block(a.id!, false);
    expect(await b.social.blocked(), isEmpty);
    expect(await b.social.author(a.username), isNotNull);
    expect(await b.social.entry(base.id), isNotNull);
  });
  test('C26 blocked third-party interactions are excluded from projected counts and comments', () async {
    await c.social.like(base.id, true);
    await c.social.comment(base.id, 'Comentario de C', newRecipeRequestId());
    final id = (await c.social.comments(base.id)).comments
        .singleWhere((v) => v.authorId == c.id)
        .id;
    await c.social.follow(a.id!, true);
    final before = (await b.social.entry(base.id))!;
    await b.social.block(c.id!, true);
    expect((await b.social.entry(base.id))!.likes, before.likes - 1);
    expect((await b.social.entry(base.id))!.comments, before.comments - 1);
    expect(
      (await b.social.comments(base.id)).comments.any((c) => c.id == id),
      false,
    );
    expect((await b.social.author(a.username))!.followers, 1);
    await b.social.block(c.id!, false);
    expect((await b.social.entry(base.id))!.likes, before.likes);
  });
  test('C24 recipe, comment and profile reports are valid, private and server-status controlled', () async {
    await b.social.report(
      ReportTarget.recipe,
      base.id,
      'Publicidad o spam repetido',
    );
    await b.social.report(
      ReportTarget.comment,
      commentId,
      'Acoso o contenido ofensivo',
    );
    await b.social.report(
      ReportTarget.profile,
      a.id!,
      'Vulneración de derechos de autor',
    );
    final reports = await b.client.from('content_reports').select();
    expect(reports.length, 3);
    expect(reports.every((r) => r['status'] == 'open'), true);
    expect(
      await c.client.from('content_reports').select().eq('reporter_id', b.id!),
      isEmpty,
    );
    await expectLater(
      b.client
          .from('content_reports')
          .update({'status': 'closed'})
          .eq('id', reports.first['id'] as String),
      throwsA(isA<PostgrestException>()),
    );
  });
  test(
    'C25 unauthorized/private/nonexistent/blocked and invalid reports rejected',
    () async {
      await expectLater(
        b.social.report(
          ReportTarget.recipe,
          privateRecipe.id,
          'Publicidad o spam repetido',
        ),
        denied,
      );
      await expectLater(
        b.social.report(
          ReportTarget.recipe,
          newRecipeRequestId(),
          'Publicidad o spam repetido',
        ),
        denied,
      );
      await b.social.block(a.id!, true);
      await expectLater(
        b.social.report(
          ReportTarget.profile,
          a.id!,
          'Acoso o contenido ofensivo',
        ),
        denied,
      );
      await b.social.block(a.id!, false);
      await expectLater(
        b.social.report(ReportTarget.recipe, base.id, 'corto'),
        throwsA(isA<CommunityFailure>()),
      );
    },
  );
  test('C10 comments paginate 8+1 without duplicates; creation quota survives deletions', () async {
    for (var i = 0; i < 9; i++) {
      await c.social.comment(
        base.id,
        'Página de comentario $i',
        newRecipeRequestId(),
      );
    }
    final first = await b.social.comments(base.id);
    expect(first.comments.length, 8);
    expect(first.cursor, isNotNull);
    final second = await b.social.comments(base.id, cursor: first.cursor);
    expect(second.comments.length, 3);
    expect(
      [...first.comments, ...second.comments].map((c) => c.id).toSet().length,
      11,
    );
    for (var i = 0; i < 10; i++) {
      await c.social.comment(base.id, 'Cuota $i', newRecipeRequestId());
    }
    final own = (await c.social.comments(base.id)).comments
        .firstWhere((v) => v.authorId == c.id);
    await c.social.deleteComment(own.id);
    await expectLater(
      c.social.comment(base.id, 'Demasiados', newRecipeRequestId()),
      throwsA(
        isA<CommunityFailure>().having(
          (e) => e.code,
          'code',
          CommunityFailureCode.quota,
        ),
      ),
    );
  });
  test(
    'C28 hybrid one-shot network loss followed by REAL server recovery',
    () async {
      b.transport.failNext = true;
      await expectLater(
        b.social.load(const CommunityQuery()),
        throwsA(
          isA<CommunityFailure>().having(
            (e) => e.code,
            'code',
            CommunityFailureCode.network,
          ),
        ),
      );
      expect((await b.social.load(const CommunityQuery())).entries, isNotEmpty);
    },
  );
  test(
    'C30 approved recipe CRUD/version/private contracts remain effective',
    () async {
      final id = await b.recipes.save(
        richDraft('Regresión Mi recetario'),
        requestId: newRecipeRequestId(),
      );
      var own = await fresh(b, id);
      expect(own.visibility, RecipeVisibility.private);
      expect(await a.recipes.read(id), isNull);
      await b.recipes.save(
        richDraft('Título actualizado'),
        previous: own,
        requestId: newRecipeRequestId(),
      );
      own = await fresh(b, id);
      expect(own.title, 'Título actualizado');
      await b.recipes.delete(own);
      expect(await b.recipes.read(id), isNull);
    },
  );
  test('C29 hybrid delayed REAL read cannot write after shared client switches B to C', () async {
    final target = publicIds.firstWhere((id) => id != base.id);
    expect((await c.social.entry(target))!.liked, false);
    b.transport.holdRecipeRead = Completer<void>();
    b.transport.readObserved = Completer<void>();
    final pending = b.social.like(target, true);
    await b.transport.readObserved!.future;
    await b.client.auth.signOut();
    await b.client.auth.signInWithPassword(
      email: c.email,
      password: c.password,
    );
    final gate = b.transport.holdRecipeRead!;
    b.transport.holdRecipeRead = null;
    gate.complete();
    await expectLater(pending, denied);
    expect((await c.social.entry(target))!.liked, false);
    await b.client.auth.signOut();
    await b.client.auth.signInWithPassword(
      email: b.email,
      password: b.password,
    );
  });
  test(
    'C26 anonymous callers cannot use new projections or comments',
    () async {
      final anon = SupabaseClient(
        endpoint,
        publicKey,
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      );
      try {
        for (final fn in [
          'community_page',
          'community_categories',
          'community_author',
          'create_comment_once',
        ]) {
          final args = switch (fn) {
            'community_author' => {'p_username': a.username},
            'create_comment_once' => {
              'p_id': newRecipeRequestId(),
              'p_recipe_id': base.id,
              'p_content': 'No autorizado',
            },
            _ => null,
          };
          await expectLater(
            anon.rpc(fn, params: args),
            throwsA(isA<PostgrestException>()),
          );
        }
      } finally {
        await anon.dispose();
      }
    },
  );
}
