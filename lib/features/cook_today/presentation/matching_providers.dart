import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/content_revision.dart';
import '../../../core/network/supabase_bootstrap.dart';
import '../../recipes/presentation/recipe_providers.dart';
import '../data/supabase_matching_repository.dart';
import '../domain/matching.dart';

final matchingRepositoryProvider = Provider<MatchingRepository?>((ref) {
  final client = ref.watch(backendProvider).client;
  return client == null ? null : SupabaseMatchingRepository(client);
});
final matchingPagesProvider = AsyncNotifierProvider.autoDispose
    .family<MatchingPages, MatchingPage, MatchingQuery>(
      MatchingPages.new,
      retry: (_, _) => null,
    );

class MatchingPages extends AsyncNotifier<MatchingPage> {
  MatchingPages(this.query);
  final MatchingQuery query;
  int generation = 0;
  @override
  Future<MatchingPage> build() async {
    generation++;
    ref.watch(contentRevisionProvider);
    final actor = ref.watch(recipeActorProvider);
    final repo = ref.watch(matchingRepositoryProvider);
    if (actor == null || repo == null || query.selected.isEmpty) {
      return const MatchingPage([]);
    }
    final cancellation = MatchingCancellation();
    ref.onDispose(cancellation.cancel);
    return repo.search(query, cancellation: cancellation);
  }

  Future<void> loadMore() async {
    final previous = state.value;
    if (state.isLoading ||
        previous == null ||
        previous.cursor == null ||
        previous.loadingMore) {
      return;
    }
    final epoch = generation, actor = ref.read(recipeActorProvider);
    final repo = ref.read(matchingRepositoryProvider);
    if (repo == null || actor == null) return;
    state = AsyncData(
      MatchingPage(
        previous.matches,
        cursor: previous.cursor,
        loadingMore: true,
      ),
    );
    final cancellation = MatchingCancellation();
    ref.onDispose(cancellation.cancel);
    try {
      final next = await repo.search(
        query,
        cursor: previous.cursor,
        cancellation: cancellation,
      );
      if (!ref.mounted ||
          generation != epoch ||
          ref.read(recipeActorProvider) != actor) {
        return;
      }
      final ids = previous.matches.map((r) => r.recipe.id).toSet();
      state = AsyncData(
        MatchingPage(
          List.unmodifiable([
            ...previous.matches,
            ...next.matches.where((r) => ids.add(r.recipe.id)),
          ]),
          cursor: next.cursor,
        ),
      );
    } catch (e) {
      if (ref.mounted &&
          generation == epoch &&
          ref.read(recipeActorProvider) == actor) {
        state = AsyncData(
          MatchingPage(
            previous.matches,
            cursor: previous.cursor,
            moreFailure: e,
          ),
        );
      }
    }
  }
}
