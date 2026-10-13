import 'community.dart';

abstract interface class CommunityRepository {
  Future<CommunityPageData> load(
    CommunityQuery query, {
    CommunityCursor? cursor,
    CommunityCancellation? cancellation,
  });
  Future<List<String>> categories();
  Future<CommunityEntry?> entry(String id);
  Future<SocialAuthor?> author(String username);
  Future<CommentPage> comments(String recipeId, {CommentCursor? cursor});
  Future<void> like(String recipeId, bool enabled);
  Future<void> save(String recipeId, bool enabled);
  Future<void> follow(String authorId, bool enabled);
  Future<void> comment(String recipeId, String content, String requestId);
  Future<void> deleteComment(String commentId);
  Future<void> block(String authorId, bool enabled);
  Future<List<String>> blocked();
  Future<void> report(ReportTarget target, String id, String reason);
}
