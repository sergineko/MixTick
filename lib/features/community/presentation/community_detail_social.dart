import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/localization/generated/app_localizations.dart';
import '../../../core/widgets/app_states.dart';
import '../../recipes/presentation/recipe_providers.dart';
import '../../recipes/presentation/recipe_widgets.dart';
import '../domain/community.dart';
import 'community_providers.dart';
import 'community_widgets.dart';

/// Gates the entire public detail on a fresh authorized social projection.
class CommunityDetailGate extends ConsumerWidget {
  const CommunityDetailGate({
    required this.recipeId,
    required this.child,
    super.key,
  });
  final String recipeId;
  final Widget child;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppLocalizations.of(context);
    if (ref.watch(communityRepositoryProvider) == null) return child;
    return ref
        .watch(socialEntryProvider(recipeId))
        .when(
          skipLoadingOnRefresh: false,
          loading: () => AppLoadingState(label: s.communityLoading),
          error: (e, _) => AppErrorState(
            message: communityError(s, e),
            actionLabel: s.retry,
            onAction: () => ref.invalidate(socialEntryProvider(recipeId)),
          ),
          data: (entry) => entry == null
              ? AppEmptyState(title: s.communityUnavailable, message: '')
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SocialProfileHint(),
                          AuthorLink(entry: entry),
                          SocialButtons(entry: entry),
                          if (entry.recipe.authorId !=
                              ref.watch(recipeActorProvider)) ...[
                            _DetailFollow(username: entry.author.username),
                            TextButton.icon(
                              onPressed: () => showReport(
                                context,
                                ref,
                                ReportTarget.recipe,
                                recipeId,
                              ),
                              icon: const Icon(Icons.flag_outlined),
                              label: Text(s.communityReportRecipe),
                            ),
                          ],
                          const SocialFeedback(),
                        ],
                      ),
                    ),
                    child,
                  ],
                ),
        );
  }
}

class _DetailFollow extends ConsumerWidget {
  const _DetailFollow({required this.username});
  final String username;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppLocalizations.of(context),
        busy = ref.watch(socialActionsProvider).busy;
    return ref
        .watch(socialAuthorProvider(username))
        .when(
          skipLoadingOnRefresh: false,
          loading: () => const SizedBox.shrink(),
          error: (_, _) => const SizedBox.shrink(),
          data: (author) => author == null
              ? const SizedBox.shrink()
              : Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: busy
                        ? null
                        : () => ref
                              .read(socialActionsProvider.notifier)
                              .run(
                                (r) => r.follow(author.id, !author.followed),
                              ),
                    icon: Icon(
                      author.followed
                          ? Icons.person_remove_outlined
                          : Icons.person_add_outlined,
                    ),
                    label: Text(
                      author.followed ? s.communityUnfollow : s.communityFollow,
                    ),
                  ),
                ),
        );
  }
}

class SocialProfileControls extends ConsumerWidget {
  const SocialProfileControls({required this.username, super.key});
  final String username;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppLocalizations.of(context),
        busy = ref.watch(socialActionsProvider).busy;
    return ref
        .watch(socialAuthorProvider(username))
        .when(
          skipLoadingOnRefresh: false,
          loading: () => const LinearProgressIndicator(),
          error: (e, _) => AppErrorState(
            message: communityError(s, e),
            actionLabel: s.retry,
            onAction: () => ref.invalidate(socialAuthorProvider(username)),
          ),
          data: (author) => author == null
              ? Text(s.profileNotFound)
              : Column(
                  children: [
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 20,
                      runSpacing: 8,
                      children: [
                        Text('${author.followers} ${s.communityFollowers}'),
                        Text('${author.following} ${s.communityFollowing}'),
                      ],
                    ),
                    if (author.id != ref.watch(recipeActorProvider)) ...[
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        key: const ValueKey('follow-author'),
                        onPressed: busy
                            ? null
                            : () => ref
                                  .read(socialActionsProvider.notifier)
                                  .run(
                                    (r) =>
                                        r.follow(author.id, !author.followed),
                                  ),
                        icon: Icon(
                          author.followed
                              ? Icons.person_remove_outlined
                              : Icons.person_add_outlined,
                        ),
                        label: Text(
                          author.followed
                              ? s.communityUnfollow
                              : s.communityFollow,
                        ),
                      ),
                      Wrap(
                        spacing: 12,
                        children: [
                          TextButton.icon(
                            key: const ValueKey('report-profile'),
                            onPressed: busy
                                ? null
                                : () => showReport(
                                    context,
                                    ref,
                                    ReportTarget.profile,
                                    author.id,
                                  ),
                            icon: const Icon(Icons.flag_outlined),
                            label: Text(s.communityReport),
                          ),
                          TextButton.icon(
                            key: const ValueKey('block-author'),
                            onPressed: busy
                                ? null
                                : () async {
                                    final actor = ref.read(recipeActorProvider);
                                    if (await recipeConfirm(
                                          context,
                                          title: s.communityBlock,
                                          message: s.communityBlockInfo,
                                          action: s.communityBlock,
                                        ) &&
                                        context.mounted &&
                                        ref.read(recipeActorProvider) ==
                                            actor) {
                                      await ref
                                          .read(socialActionsProvider.notifier)
                                          .run((r) => r.block(author.id, true));
                                    }
                                  },
                            icon: const Icon(Icons.block),
                            label: Text(s.communityBlock),
                          ),
                        ],
                      ),
                    ],
                    const SocialFeedback(),
                  ],
                ),
        );
  }
}
