import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/content_revision.dart';
import '../../../core/network/supabase_bootstrap.dart';
import '../../profile/presentation/profile_providers.dart';
import '../../recipes/presentation/recipe_providers.dart';
import '../data/supabase_community_repository.dart';
import '../domain/community.dart';
import '../domain/community_repository.dart';

final communityRepositoryProvider = Provider<CommunityRepository?>((ref) {
  final client = ref.watch(backendProvider).client;
  return client == null ? null : SupabaseCommunityRepository(client);
});
final canParticipateProvider = Provider<bool>((ref) {
  final profile = ref.watch(ownProfileProvider);
  return !profile.isLoading && !profile.hasError && profile.value != null;
});
final communityPagesProvider = AsyncNotifierProvider.autoDispose
    .family<CommunityPages, CommunityPageData, CommunityQuery>(
      CommunityPages.new,
    );

class CommunityPages extends AsyncNotifier<CommunityPageData> {
  CommunityPages(this.query);
  final CommunityQuery query;
  int generation = 0;
  @override
  Future<CommunityPageData> build() async {
    generation++;
    ref.watch(contentRevisionProvider);
    final actor = ref.watch(recipeActorProvider);
    final repo = ref.watch(communityRepositoryProvider);
    if (actor == null || repo == null) return const CommunityPageData([]);
    final cancellation = CommunityCancellation();
    ref.onDispose(cancellation.cancel);
    return repo.load(query, cancellation: cancellation);
  }

  Future<void> loadMore() async {
    final previous = state.value;
    if (previous == null ||
        previous.cursor == null ||
        previous.loadingMore ||
        state.isLoading) {
      return;
    }
    final epoch = generation, actor = ref.read(recipeActorProvider);
    final repo = ref.read(communityRepositoryProvider);
    if (repo == null || actor == null) return;
    state = AsyncData(
      CommunityPageData(
        previous.entries,
        cursor: previous.cursor,
        loadingMore: true,
      ),
    );
    try {
      final cancellation = CommunityCancellation();
      ref.onDispose(cancellation.cancel);
      final next = await repo.load(
        query,
        cursor: previous.cursor,
        cancellation: cancellation,
      );
      if (!ref.mounted ||
          epoch != generation ||
          ref.read(recipeActorProvider) != actor) {
        return;
      }
      final ids = previous.entries.map((r) => r.recipe.id).toSet();
      state = AsyncData(
        CommunityPageData(
          List.unmodifiable([
            ...previous.entries,
            ...next.entries.where((r) => ids.add(r.recipe.id)),
          ]),
          cursor: next.cursor,
        ),
      );
    } catch (e) {
      if (ref.mounted &&
          epoch == generation &&
          ref.read(recipeActorProvider) == actor) {
        state = AsyncData(
          CommunityPageData(
            previous.entries,
            cursor: previous.cursor,
            moreFailure: e,
          ),
        );
      }
    }
  }
}

final communityCategoriesProvider = FutureProvider.autoDispose<List<String>>((
  ref,
) async {
  ref.watch(contentRevisionProvider);
  if (ref.watch(recipeActorProvider) == null) return [];
  return await ref.watch(communityRepositoryProvider)?.categories() ?? [];
});
final socialEntryProvider = FutureProvider.autoDispose
    .family<CommunityEntry?, String>((ref, id) async {
      ref.watch(contentRevisionProvider);
      if (ref.watch(recipeActorProvider) == null) return null;
      return ref.watch(communityRepositoryProvider)?.entry(id);
    });
final socialAuthorProvider = FutureProvider.autoDispose
    .family<SocialAuthor?, String>((ref, username) async {
      ref.watch(contentRevisionProvider);
      if (ref.watch(recipeActorProvider) == null) return null;
      return ref.watch(communityRepositoryProvider)?.author(username);
    });
final blockedAuthorsProvider = FutureProvider.autoDispose<List<String>>((
  ref,
) async {
  ref.watch(contentRevisionProvider);
  if (ref.watch(recipeActorProvider) == null) return [];
  return await ref.watch(communityRepositoryProvider)?.blocked() ?? [];
});
final commentsProvider = AsyncNotifierProvider.autoDispose
    .family<CommentsController, CommentPage, String>(CommentsController.new);

class CommentsController extends AsyncNotifier<CommentPage> {
  CommentsController(this.recipeId);
  final String recipeId;
  int generation = 0;
  @override
  Future<CommentPage> build() async {
    generation++;
    ref.watch(contentRevisionProvider);
    if (ref.watch(recipeActorProvider) == null) return const CommentPage([]);
    return await ref.watch(communityRepositoryProvider)?.comments(recipeId) ??
        const CommentPage([]);
  }

  Future<void> loadMore() async {
    final previous = state.value;
    if (previous == null ||
        previous.cursor == null ||
        previous.loadingMore ||
        state.isLoading) {
      return;
    }
    final epoch = generation, actor = ref.read(recipeActorProvider);
    final repo = ref.read(communityRepositoryProvider);
    if (repo == null || actor == null) return;
    state = AsyncData(
      CommentPage(
        previous.comments,
        cursor: previous.cursor,
        loadingMore: true,
      ),
    );
    try {
      final next = await repo.comments(recipeId, cursor: previous.cursor);
      if (!ref.mounted ||
          epoch != generation ||
          ref.read(recipeActorProvider) != actor) {
        return;
      }
      final ids = previous.comments.map((c) => c.id).toSet();
      state = AsyncData(
        CommentPage(
          List.unmodifiable([
            ...previous.comments,
            ...next.comments.where((c) => ids.add(c.id)),
          ]),
          cursor: next.cursor,
        ),
      );
    } catch (e) {
      if (ref.mounted &&
          epoch == generation &&
          ref.read(recipeActorProvider) == actor) {
        state = AsyncData(
          CommentPage(
            previous.comments,
            cursor: previous.cursor,
            moreFailure: e,
          ),
        );
      }
    }
  }
}

class SocialActionState {
  const SocialActionState({this.busy = false, this.failure});
  final bool busy;
  final CommunityFailureCode? failure;
}

final socialActionsProvider =
    NotifierProvider<SocialActions, SocialActionState>(SocialActions.new);

class SocialActions extends Notifier<SocialActionState> {
  int generation = 0;
  @override
  SocialActionState build() {
    ref.watch(recipeActorProvider);
    generation++;
    return const SocialActionState();
  }

  Future<bool> run(Future<void> Function(CommunityRepository) action) async {
    if (state.busy) return false;
    final actor = ref.read(recipeActorProvider), epoch = generation;
    final repo = ref.read(communityRepositoryProvider);
    if (actor == null || repo == null) return false;
    state = const SocialActionState(busy: true);
    CommunityFailureCode? failure;
    try {
      await action(repo);
    } catch (e) {
      failure = e is CommunityFailure
          ? e.code
          : CommunityFailureCode.unexpected;
    }
    if (!ref.mounted ||
        epoch != generation ||
        ref.read(recipeActorProvider) != actor) {
      return false;
    }
    // Also reconcile ambiguous/failed writes. Never guess totals in the client.
    ref.read(contentRevisionProvider.notifier).changed();
    ref.invalidate(recipeDetailProvider);
    ref.invalidate(recipePhotoProvider);
    ref.invalidate(publicProfileProvider);
    ref.invalidate(avatarProvider);
    state = SocialActionState(failure: failure);
    return failure == null;
  }
}
