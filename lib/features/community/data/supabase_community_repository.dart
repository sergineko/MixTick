import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/community.dart';
import '../domain/community_repository.dart';

class SupabaseCommunityRepository implements CommunityRepository {
  const SupabaseCommunityRepository(this.client);
  final SupabaseClient client;
  static const pageSize = 8;
  String get actor =>
      client.auth.currentUser?.id ??
      (throw const CommunityFailure(CommunityFailureCode.forbidden));
  void _sameActor(String uid) {
    if (actor != uid) {
      throw const CommunityFailure(CommunityFailureCode.forbidden);
    }
  }

  Future<T> _run<T>(Future<T> Function() operation) async {
    try {
      final uid = actor;
      final value = await operation();
      if (actor != uid) {
        throw const CommunityFailure(CommunityFailureCode.forbidden);
      }
      return value;
    } on CommunityFailure {
      rethrow;
    } on SocketException {
      throw const CommunityFailure(CommunityFailureCode.network);
    } on http.ClientException {
      throw const CommunityFailure(CommunityFailureCode.network);
    } on TimeoutException {
      throw const CommunityFailure(CommunityFailureCode.network);
    } on PostgrestException catch (e) {
      throw CommunityFailure(switch (e.code) {
        '42501' || 'PGRST301' || 'PGRST303' => CommunityFailureCode.forbidden,
        'PT429' => CommunityFailureCode.quota,
        'PT409' || '23505' => CommunityFailureCode.conflict,
        '22023' ||
        '23514' ||
        '23503' ||
        '22P02' => CommunityFailureCode.invalid,
        _ => CommunityFailureCode.unexpected,
      });
    } catch (_) {
      throw const CommunityFailure(CommunityFailureCode.unexpected);
    }
  }

  @override
  Future<CommunityPageData> load(
    CommunityQuery query, {
    CommunityCursor? cursor,
    CommunityCancellation? cancellation,
  }) => _run(() async {
    final request = client.rpc(
      'community_page',
      params: {
        'p_search': query.search.trim(),
        'p_category': query.category,
        'p_author': query.author,
        'p_saved': query.saved,
        'p_before': cursor?.publishedAt.toUtc().toIso8601String(),
        'p_before_id': cursor?.id,
        'p_limit': pageSize + 1,
      },
    );
    final rows =
        await (cancellation == null
                ? request
                : request.abortSignal(cancellation.signal))
            as List;
    final entries = rows
        .take(pageSize)
        .map((r) => CommunityEntry.fromJson(r as Map<String, dynamic>))
        .toList();
    return CommunityPageData(
      List.unmodifiable(entries),
      cursor: rows.length > pageSize
          ? CommunityCursor(entries.last.publishedAt, entries.last.recipe.id)
          : null,
    );
  });
  @override
  Future<List<String>> categories() => _run(
    () async =>
        (await client.rpc('community_categories') as List).cast<String>(),
  );
  @override
  Future<CommunityEntry?> entry(String id) => _run(() async {
    final rows = await client.rpc(
      'community_page',
      params: {'p_recipe_id': id, 'p_limit': 1},
    ) as List;
    return rows.isEmpty
        ? null
        : CommunityEntry.fromJson(rows.single as Map<String, dynamic>);
  });
  @override
  Future<SocialAuthor?> author(String username) => _run(() async {
    final row = await client.rpc(
      'community_author',
      params: {'p_username': username},
    );
    return row == null
        ? null
        : SocialAuthor.fromJson(row as Map<String, dynamic>);
  });
  @override
  Future<CommentPage> comments(String recipeId, {CommentCursor? cursor}) =>
      _run(() async {
        await _accessible(recipeId);
        var q = client
            .from('recipe_comments')
            .select(
              'id,author_id,content,created_at,profiles!inner(username,display_name,avatar_path)',
            )
            .eq('recipe_id', recipeId);
        if (cursor != null) {
          if (!RegExp(r'^[0-9a-f-]{36}$').hasMatch(cursor.id)) {
            throw const CommunityFailure(CommunityFailureCode.invalid);
          }
          final stamp = cursor.createdAt.toUtc().toIso8601String();
          q = q.or(
            'created_at.lt.$stamp,and(created_at.eq.$stamp,id.lt.${cursor.id})',
          );
        }
        final rows = await q
            .order('created_at', ascending: false)
            .order('id', ascending: false)
            .limit(pageSize + 1);
        final values = rows.take(pageSize).map(RecipeComment.fromJson).toList();
        return CommentPage(
          List.unmodifiable(values),
          cursor: rows.length > pageSize
              ? CommentCursor(values.last.createdAt, values.last.id)
              : null,
        );
      });
  Future<void> _accessible(String id) async {
    final row = await client
        .from('recipes')
        .select('id')
        .eq('id', id)
        .eq('visibility', 'public')
        .maybeSingle();
    if (row == null) {
      throw const CommunityFailure(CommunityFailureCode.forbidden);
    }
  }

  Future<void> _insertOnce(String table, Map<String, dynamic> values) async {
    try {
      await client.from(table).insert(values);
    } on PostgrestException catch (e) {
      if (e.code != '23505') rethrow;
    }
  }

  Future<void> _recipeRelation(String table, String id, bool enabled) =>
      _run(() async {
        final uid = actor;
        await _accessible(id);
        _sameActor(uid);
        if (enabled) {
          await _insertOnce(table, {'recipe_id': id});
        } else {
          await client
              .from(table)
              .delete()
              .eq('recipe_id', id)
              .eq('user_id', actor);
        }
      });
  @override
  Future<void> like(String recipeId, bool enabled) =>
      _recipeRelation('recipe_likes', recipeId, enabled);
  @override
  Future<void> save(String recipeId, bool enabled) =>
      _recipeRelation('recipe_saves', recipeId, enabled);
  @override
  Future<void> follow(String authorId, bool enabled) => _run(() async {
    final uid = actor;
    if (authorId == actor) {
      throw const CommunityFailure(CommunityFailureCode.invalid);
    }
    final visible = await client
        .from('profiles')
        .select('user_id')
        .eq('user_id', authorId)
        .maybeSingle();
    _sameActor(uid);
    if (visible == null) {
      throw const CommunityFailure(CommunityFailureCode.forbidden);
    }
    if (enabled) {
      await _insertOnce('user_follows', {'followed_id': authorId});
    } else {
      await client
          .from('user_follows')
          .delete()
          .eq('followed_id', authorId)
          .eq('follower_id', actor);
    }
  });
  @override
  Future<void> comment(String recipeId, String content, String requestId) =>
      _run(() async {
        if (!RecipeComment.valid(content)) {
          throw const CommunityFailure(CommunityFailureCode.invalid);
        }
        await client.rpc(
          'create_comment_once',
          params: {
            'p_id': requestId,
            'p_recipe_id': recipeId,
            'p_content': content.trim(),
          },
        );
      });
  @override
  Future<void> deleteComment(String commentId) => _run(() async {
    final uid = actor;
    final row = await client
        .from('recipe_comments')
        .select('recipe_id,author_id')
        .eq('id', commentId)
        .maybeSingle();
    _sameActor(uid);
    if (row == null || row['author_id'] != actor) {
      throw const CommunityFailure(CommunityFailureCode.forbidden);
    }
    await _accessible(row['recipe_id'] as String);
    _sameActor(uid);
    final removed = await client
        .from('recipe_comments')
        .delete()
        .eq('id', commentId)
        .eq('author_id', actor)
        .select('id');
    if (removed.isEmpty) {
      throw const CommunityFailure(CommunityFailureCode.forbidden);
    }
  });
  @override
  Future<void> block(String authorId, bool enabled) => _run(() async {
    if (authorId == actor) {
      throw const CommunityFailure(CommunityFailureCode.invalid);
    }
    if (enabled) {
      await _insertOnce('user_blocks', {'blocked_id': authorId});
    } else {
      await client
          .from('user_blocks')
          .delete()
          .eq('blocked_id', authorId)
          .eq('blocker_id', actor);
    }
  });
  @override
  Future<List<String>> blocked() => _run(
    () async =>
        (await client
                .from('user_blocks')
                .select('blocked_id')
                .eq('blocker_id', actor)
                .order('created_at'))
            .map((r) => r['blocked_id'] as String)
            .toList(),
  );
  @override
  Future<void> report(ReportTarget target, String id, String reason) =>
      _run(() async {
        if (reason.trim().runes.length < 10 ||
            reason.trim().runes.length > 1000) {
          throw const CommunityFailure(CommunityFailureCode.invalid);
        }
        await client.rpc(
          'submit_report',
          params: {
            'p_target_type': target.name,
            'p_target_id': id,
            'p_reason': reason.trim(),
          },
        );
      });
}
