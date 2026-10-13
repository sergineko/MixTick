import 'dart:async';

import '../../profile/domain/user_profile.dart';
import '../../recipes/domain/recipe.dart';

enum CommunityFailureCode {
  network,
  forbidden,
  invalid,
  quota,
  conflict,
  unexpected,
}

class CommunityCancellation {
  final _abort = Completer<void>();
  Future<void> get signal => _abort.future;
  void cancel() {
    if (!_abort.isCompleted) _abort.complete();
  }
}

class CommunityFailure implements Exception {
  const CommunityFailure(this.code);
  final CommunityFailureCode code;
  @override
  String toString() => 'CommunityFailure(${code.name})';
}

class CommunityEntry {
  const CommunityEntry({
    required this.recipe,
    required this.author,
    required this.publishedAt,
    this.likes = 0,
    this.comments = 0,
    this.liked = false,
    this.saved = false,
  });
  final Recipe recipe;
  final PublicProfile author;
  final DateTime publishedAt;
  final int likes, comments;
  final bool liked, saved;
  factory CommunityEntry.fromJson(Map<String, dynamic> j) => CommunityEntry(
    recipe: Recipe.fromJson(j['recipe'] as Map<String, dynamic>),
    author: PublicProfile.fromJson(j['author'] as Map<String, dynamic>),
    publishedAt: DateTime.parse(j['published_at'] as String),
    likes: j['likes'] as int,
    comments: j['comments'] as int,
    liked: j['liked'] as bool,
    saved: j['saved'] as bool,
  );
}

class CommunityQuery {
  const CommunityQuery({
    this.search = '',
    this.category,
    this.author,
    this.saved = false,
  });
  final String search;
  final String? category, author;
  final bool saved;
  @override
  bool operator ==(Object other) =>
      other is CommunityQuery &&
      search == other.search &&
      category == other.category &&
      author == other.author &&
      saved == other.saved;
  @override
  int get hashCode => Object.hash(search, category, author, saved);
}

class CommunityCursor {
  const CommunityCursor(this.publishedAt, this.id);
  final DateTime publishedAt;
  final String id;
}

class CommunityPageData {
  const CommunityPageData(
    this.entries, {
    this.cursor,
    this.loadingMore = false,
    this.moreFailure,
  });
  final List<CommunityEntry> entries;
  final CommunityCursor? cursor;
  final bool loadingMore;
  final Object? moreFailure;
}

class SocialAuthor {
  const SocialAuthor({
    required this.id,
    required this.profile,
    this.followers = 0,
    this.following = 0,
    this.followed = false,
  });
  final String id;
  final PublicProfile profile;
  final int followers, following;
  final bool followed;
  factory SocialAuthor.fromJson(Map<String, dynamic> j) => SocialAuthor(
    id: j['id'] as String,
    profile: PublicProfile.fromJson(j['profile'] as Map<String, dynamic>),
    followers: j['followers'] as int,
    following: j['following'] as int,
    followed: j['followed'] as bool,
  );
}

class RecipeComment {
  const RecipeComment({
    required this.id,
    required this.authorId,
    required this.author,
    required this.content,
    required this.createdAt,
  });
  final String id, authorId, content;
  final PublicProfile author;
  final DateTime createdAt;
  static bool valid(String value) =>
      value.trim().runes.isNotEmpty && value.trim().runes.length <= 2000;
  factory RecipeComment.fromJson(Map<String, dynamic> j) => RecipeComment(
    id: j['id'] as String,
    authorId: j['author_id'] as String,
    author: PublicProfile.fromJson(j['profiles'] as Map<String, dynamic>),
    content: j['content'] as String,
    createdAt: DateTime.parse(j['created_at'] as String),
  );
}

class CommentCursor {
  const CommentCursor(this.createdAt, this.id);
  final DateTime createdAt;
  final String id;
}

class CommentPage {
  const CommentPage(
    this.comments, {
    this.cursor,
    this.loadingMore = false,
    this.moreFailure,
  });
  final List<RecipeComment> comments;
  final CommentCursor? cursor;
  final bool loadingMore;
  final Object? moreFailure;
}

enum ReportTarget { recipe, comment, profile }
