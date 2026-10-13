// UI/state fixtures only. Real RLS is exercised separately in community_local.
import 'dart:async';

import 'package:mixtick/features/community/domain/community.dart';
import 'package:mixtick/features/community/domain/community_repository.dart';
import 'package:mixtick/features/profile/domain/user_profile.dart';
import 'package:mixtick/features/recipes/domain/recipe.dart';

import 'fake_recipe_repository.dart';

const communityAuthor = PublicProfile(
  username: 'test_author',
  displayName: 'Autora de prueba',
);
CommunityEntry socialFixture({
  String id = '20000000-0000-4000-8000-000000000001',
  String title = 'Tortilla de prueba',
}) => CommunityEntry(
  recipe: testRecipe(id: id, title: title, visibility: RecipeVisibility.public),
  author: communityAuthor,
  publishedAt: DateTime.utc(2026, 10, 13),
);

class FakeCommunityRepository implements CommunityRepository {
  final rows = <String, CommunityEntry>{};
  final liked = <String>{},
      saved = <String>{},
      follows = <String>{},
      blocks = <String>{};
  final notes = <String, RecipeComment>{};
  final queries = <CommunityQuery>[];
  int writes = 0;
  CommunityFailure? failure;
  Completer<void>? pendingWrite;
  Completer<CommunityPageData>? pendingPage;
  bool unavailable = false;
  CommunityEntry? current(String id) {
    final r = rows[id];
    if (r == null || unavailable || blocks.contains(r.recipe.authorId)) {
      return null;
    }
    return CommunityEntry(
      recipe: r.recipe,
      author: r.author,
      publishedAt: r.publishedAt,
      likes: liked.contains(id) ? 1 : 0,
      comments: notes.length,
      liked: liked.contains(id),
      saved: saved.contains(id),
    );
  }

  @override
  Future<CommunityPageData> load(
    CommunityQuery query, {
    CommunityCursor? cursor,
    CommunityCancellation? cancellation,
  }) async {
    queries.add(query);
    if (pendingPage != null) return pendingPage!.future;
    if (failure != null) throw failure!;
    final all = rows.keys
        .map(current)
        .whereType<CommunityEntry>()
        .where(
          (r) =>
              (!query.saved || r.saved) &&
              (query.category == null || query.category == r.recipe.category) &&
              r.recipe.title.toLowerCase().contains(query.search.toLowerCase()),
        )
        .toList();
    if (cursor == null && all.length > 2) {
      return CommunityPageData(
        all.take(2).toList(),
        cursor: CommunityCursor(all[1].publishedAt, all[1].recipe.id),
      );
    }
    if (cursor != null) {
      return CommunityPageData(
        all.skip(1).toList(),
      ); // Deliberate overlap tests deduplication.
    }
    return CommunityPageData(all);
  }

  @override
  Future<List<String>> categories() async => ['Principal'];
  @override
  Future<CommunityEntry?> entry(String id) async => current(id);
  @override
  Future<SocialAuthor?> author(String username) async =>
      blocks.contains('test-a')
      ? null
      : SocialAuthor(
          id: 'test-a',
          profile: communityAuthor,
          followers: follows.length,
          followed: follows.contains('test-a'),
        );
  @override
  Future<CommentPage> comments(
    String recipeId, {
    CommentCursor? cursor,
  }) async => CommentPage(notes.values.toList());
  Future<void> change(VoidCallback action) async {
    writes++;
    await pendingWrite?.future;
    if (failure != null) throw failure!;
    action();
  }

  @override
  Future<void> like(String recipeId, bool enabled) =>
      change(() => enabled ? liked.add(recipeId) : liked.remove(recipeId));
  @override
  Future<void> save(String recipeId, bool enabled) =>
      change(() => enabled ? saved.add(recipeId) : saved.remove(recipeId));
  @override
  Future<void> follow(String authorId, bool enabled) =>
      change(() => enabled ? follows.add(authorId) : follows.remove(authorId));
  @override
  Future<void> comment(String recipeId, String content, String requestId) =>
      change(
        () => notes[requestId] = RecipeComment(
          id: requestId,
          authorId: 'test-b',
          author: const PublicProfile(
            username: 'test_b',
            displayName: 'Prueba B',
          ),
          content: content,
          createdAt: DateTime.now(),
        ),
      );
  @override
  Future<void> deleteComment(String commentId) =>
      change(() => notes.remove(commentId));
  @override
  Future<void> block(String authorId, bool enabled) =>
      change(() => enabled ? blocks.add(authorId) : blocks.remove(authorId));
  @override
  Future<List<String>> blocked() async => blocks.toList();
  @override
  Future<void> report(ReportTarget target, String id, String reason) =>
      change(() {});
}

typedef VoidCallback = void Function();
