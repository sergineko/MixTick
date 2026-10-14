import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../cook_today/domain/matching.dart';
import '../../recipes/domain/recipe.dart';
import '../domain/shopping.dart';
import '../domain/shopping_repository.dart';

class SupabaseShoppingRepository implements ShoppingRepository {
  const SupabaseShoppingRepository(this.client);
  final SupabaseClient client;
  String get actor =>
      client.auth.currentUser?.id ??
      (throw const ShoppingFailure(ShoppingFailureCode.forbidden));
  Future<T> run<T>(Future<T> Function() operation) async {
    try {
      final uid = actor;
      final result = await operation();
      if (actor != uid) {
        throw const ShoppingFailure(ShoppingFailureCode.forbidden);
      }
      return result;
    } on ShoppingFailure {
      rethrow;
    } on SocketException {
      throw const ShoppingFailure(ShoppingFailureCode.network);
    } on http.ClientException {
      throw const ShoppingFailure(ShoppingFailureCode.network);
    } on TimeoutException {
      throw const ShoppingFailure(ShoppingFailureCode.network);
    } on PostgrestException catch (e) {
      throw ShoppingFailure(switch (e.code) {
        'PT409' || '23505' => ShoppingFailureCode.conflict,
        '42501' || 'PGRST301' || 'PGRST303' => ShoppingFailureCode.forbidden,
        '22023' ||
        '23514' ||
        '22P02' ||
        '22003' ||
        '23502' => ShoppingFailureCode.invalid,
        'PT429' => ShoppingFailureCode.quota,
        _ => ShoppingFailureCode.unexpected,
      });
    } catch (_) {
      throw const ShoppingFailure(ShoppingFailureCode.unexpected);
    }
  }

  @override
  Future<ShoppingOverview> overview() => run(() async {
    final lists = <ShoppingList>[];
    String? after;
    while (true) {
      var query = client
          .from('shopping_lists')
          .select('*,shopping_list_members(user_id)');
      if (after != null) query = query.gt('id', after);
      final rows = await query.order('id').limit(200);
      lists.addAll(rows.map(ShoppingList.fromJson));
      if (rows.length < 200) break;
      after = rows.last['id'] as String;
    }
    final invitations = await client.rpc('shopping_invitation_inbox');
    return ShoppingOverview(
      List.unmodifiable(lists),
      List.unmodifiable(
        (invitations as List).map(
          (j) => ShoppingInvitation.fromJson(j as Map<String, dynamic>),
        ),
      ),
    );
  });
  @override
  Future<ShoppingSnapshot> read(String listId) => run(() async {
    final data = await client.rpc(
      'shopping_list_snapshot',
      params: {'p_list_id': listId},
    );
    if (data == null) {
      throw const ShoppingFailure(ShoppingFailureCode.forbidden);
    }
    return ShoppingSnapshot.fromJson(data as Map<String, dynamic>);
  });
  @override
  Future<String> createList(String title, String requestId) => run(
    () async => await client.rpc(
      'create_shopping_list_once',
      params: {'p_request_id': requestId, 'p_title': title.trim()},
    ) as String,
  );
  @override
  Future<void> rename(ShoppingList list, String title) => run(() async {
    final rows = await client
        .from('shopping_lists')
        .update({'title': title.trim()})
        .eq('id', list.id)
        .eq('version', list.version)
        .select('id');
    if (rows.isEmpty) {
      if ((await read(list.id)).list.ownerId != actor) {
        throw const ShoppingFailure(ShoppingFailureCode.forbidden);
      }
      throw const ShoppingFailure(ShoppingFailureCode.conflict);
    }
  });
  @override
  Future<void> deleteList(ShoppingList list) => run(() async {
    final rows = await client
        .from('shopping_lists')
        .delete()
        .eq('id', list.id)
        .eq('version', list.version)
        .select('id');
    if (rows.isEmpty) {
      await read(list.id);
      throw const ShoppingFailure(ShoppingFailureCode.conflict);
    }
  });
  @override
  Future<String> add(String listId, ShoppingDraft draft, String requestId) =>
      run(() async {
        if (!draft.valid) {
          throw const ShoppingFailure(ShoppingFailureCode.invalid);
        }
        return await client.rpc(
          'add_shopping_item_once',
          params: {
            'p_list_id': listId,
            'p_request_id': requestId,
            'p_item': draft.json,
          },
        ) as String;
      });
  Future<void> change(ShoppingItem item, Map<String, dynamic> changes) =>
      run(() async {
        await client.rpc(
          'update_shopping_item',
          params: {
            'p_item_id': item.id,
            'p_expected_version': item.version,
            'p_changes': changes,
          },
        );
      });
  @override
  Future<void> edit(ShoppingItem item, ShoppingDraft draft) async {
    if (!draft.valid) throw const ShoppingFailure(ShoppingFailureCode.invalid);
    await change(item, draft.changes);
  }

  @override
  Future<void> toggle(ShoppingItem item) =>
      change(item, {'is_purchased': !item.purchased});
  @override
  Future<void> remove(ShoppingItem item) => run(() async {
    await client.rpc(
      'delete_shopping_item',
      params: {'p_item_id': item.id, 'p_expected_version': item.version},
    );
  });
  @override
  Future<void> invite(String listId, String username) => run(() async {
    await client.rpc(
      'invite_to_list',
      params: {
        'p_list_id': listId,
        'p_username': username.trim().toLowerCase(),
      },
    );
  });
  @override
  Future<void> respond(ShoppingInvitation invitation, bool accept) =>
      run(() async {
        await client.rpc(
          'respond_to_invitation',
          params: {'p_invitation_id': invitation.id, 'p_accept': accept},
        );
      });
  @override
  Future<void> revoke(String listId, String userId) => run(() async {
    await client.rpc(
      'revoke_list_member',
      params: {'p_list_id': listId, 'p_user_id': userId},
    );
  });
  @override
  Future<void> leave(String listId) => run(() async {
    await client.rpc('leave_list', params: {'p_list_id': listId});
  });
  @override
  Future<ShoppingImportPreview> preview(String recipeId) => run(() async {
    final data = await client.rpc(
      'shopping_recipe_preview',
      params: {'p_recipe_id': recipeId},
    );
    if (data == null) {
      throw const ShoppingFailure(ShoppingFailureCode.forbidden);
    }
    return ShoppingImportPreview.fromJson(data as Map<String, dynamic>);
  });
  @override
  Future<List<String>> importIngredients(
    String listId,
    ShoppingImportPreview preview,
    List<MissingIngredient> lines,
    String requestId, {
    bool missingOnly = false,
  }) => run(() async {
    final ids = await client.rpc(
      'import_recipe_checked',
      params: {
        'p_list_id': listId,
        'p_recipe_id': preview.recipeId,
        'p_expected_version': preview.version,
        'p_request_id': requestId,
        'p_line_ids': lines.map((i) => i.lineId).toList(),
        'p_ordinals': lines.map((i) => i.ordinal).toList(),
        'p_missing_only': missingOnly,
      },
    );
    return List<String>.unmodifiable(ids as List);
  });
  @override
  Stream<ShoppingSignal> watch(String listId) {
    late StreamController<ShoppingSignal> stream;
    RealtimeChannel? channel;
    StreamSubscription<AuthState>? auth;
    String? uid;
    var alive = true;
    void signal(ShoppingSignal value) {
      if (alive &&
          uid != null &&
          client.auth.currentUser?.id == uid &&
          !stream.isClosed) {
        stream.add(value);
      }
    }

    Future<void> dispose() async {
      alive = false;
      await auth?.cancel();
      if (channel != null) await client.removeChannel(channel!);
    }

    stream = StreamController<ShoppingSignal>(
      onListen: () async {
        try {
          uid = actor;
          // Do not even open a channel before a successful authorized snapshot.
          await read(listId);
          if (!alive || uid != client.auth.currentUser?.id) return;
          auth = client.auth.onAuthStateChange.listen((_) {
            if (client.auth.currentUser?.id != uid) {
              unawaited(dispose());
              unawaited(stream.close());
            }
          });
          signal(ShoppingSignal.connecting);
          channel = client.channel('shopping:$listId:${newRecipeRequestId()}');
          for (final entry in {
            'shopping_lists': 'id',
            'shopping_items': 'list_id',
          }.entries) {
            for (final event in [
              PostgresChangeEvent.insert,
              PostgresChangeEvent.update,
            ]) {
              channel!.onPostgresChanges(
                event: event,
                schema: 'public',
                table: entry.key,
                filter: PostgresChangeFilter(
                  type: PostgresChangeFilterType.eq,
                  column: entry.value,
                  value: listId,
                ),
                callback: (_) => signal(ShoppingSignal.changed),
              );
            }
          }
          channel!.onSystemEvents((payload) {
            if (payload is Map && payload['status'] == 'ok') {
              signal(ShoppingSignal.connected);
            }
          });
          channel!.subscribe(
            (status, error) => signal(
              status == RealtimeSubscribeStatus.subscribed
                  ? ShoppingSignal.connecting
                  : ShoppingSignal.disconnected,
            ),
          );
        } catch (error) {
          if (alive && !stream.isClosed) stream.addError(error);
        }
      },
      onCancel: dispose,
    );
    return stream.stream;
  }
}
