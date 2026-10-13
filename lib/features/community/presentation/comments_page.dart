import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/localization/generated/app_localizations.dart';
import '../../../core/widgets/app_states.dart';
import '../../../core/widgets/access_revalidation.dart';
import '../../recipes/domain/recipe.dart';
import '../../recipes/presentation/recipe_providers.dart';
import '../../recipes/presentation/recipe_widgets.dart';
import '../domain/community.dart';
import 'community_providers.dart';
import 'community_widgets.dart';

class CommentsPage extends ConsumerStatefulWidget {
  const CommentsPage({required this.recipeId, super.key});
  final String recipeId;
  @override
  ConsumerState<CommentsPage> createState() => _CommentsPageState();
}

class _CommentsPageState extends ConsumerState<CommentsPage> {
  final content = TextEditingController();
  final form = GlobalKey<FormState>();
  String requestId = newRecipeRequestId();
  void refresh() {
    ref.invalidate(recipeDetailProvider(widget.recipeId));
    ref.invalidate(commentsProvider(widget.recipeId));
    ref.invalidate(recipePhotoProvider);
  }

  @override
  void dispose() {
    content.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context),
        action = ref.watch(socialActionsProvider),
        actor = ref.watch(recipeActorProvider);
    return AccessRevalidation(
      onRevalidate: refresh,
      child: Scaffold(
        appBar: AppBar(
          title: Text(s.communityComments),
          actions: [
            IconButton(
              tooltip: s.recipeReload,
              onPressed: refresh,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: SafeArea(
          child: ref
              .watch(recipeDetailProvider(widget.recipeId))
              .when(
                skipLoadingOnRefresh: false,
                loading: () => AppLoadingState(label: s.communityLoading),
                error: (e, _) => AppErrorState(
                  message: recipeError(s, e),
                  actionLabel: s.retry,
                  onAction: refresh,
                ),
                data: (recipe) =>
                    recipe == null ||
                        recipe.visibility != RecipeVisibility.public
                    ? AppEmptyState(title: s.communityUnavailable, message: '')
                    : ref
                          .watch(commentsProvider(widget.recipeId))
                          .when(
                            skipLoadingOnRefresh: false,
                            loading: () =>
                                AppLoadingState(label: s.communityLoading),
                            error: (e, _) => AppErrorState(
                              message: communityError(s, e),
                              actionLabel: s.retry,
                              onAction: refresh,
                            ),
                            data: (page) => RefreshIndicator(
                              onRefresh: () async {
                                refresh();
                              },
                              child: ListView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                padding: const EdgeInsets.all(20),
                                children: [
                                  Text(
                                    recipe.title,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge,
                                  ),
                                  const SizedBox(height: 20),
                                  Form(
                                    // Profile onboarding is shared with the feed.
                                    key: form,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        TextFormField(
                                          key: const ValueKey('comment-input'),
                                          controller: content,
                                          enabled:
                                              !action.busy &&
                                              ref.watch(canParticipateProvider),
                                          maxLength: 2000,
                                          minLines: 2,
                                          maxLines: 6,
                                          decoration: InputDecoration(
                                            labelText: s.communityWriteComment,
                                            border: const OutlineInputBorder(),
                                          ),
                                          validator: (v) =>
                                              RecipeComment.valid(v ?? '')
                                              ? null
                                              : s.communityCommentInvalid,
                                        ),
                                        FilledButton.icon(
                                          key: const ValueKey('send-comment'),
                                          onPressed:
                                              action.busy ||
                                                  !ref.watch(
                                                    canParticipateProvider,
                                                  )
                                              ? null
                                              : () async {
                                                  if (!form.currentState!
                                                      .validate()) {
                                                    return;
                                                  }
                                                  final sent = await ref
                                                      .read(
                                                        socialActionsProvider
                                                            .notifier,
                                                      )
                                                      .run(
                                                        (r) => r.comment(
                                                          widget.recipeId,
                                                          content.text,
                                                          requestId,
                                                        ),
                                                      );
                                                  if (mounted &&
                                                      ref.read(
                                                            recipeActorProvider,
                                                          ) ==
                                                          actor &&
                                                      sent) {
                                                    content.clear();
                                                    requestId =
                                                        newRecipeRequestId();
                                                  }
                                                },
                                          icon: const Icon(Icons.send_outlined),
                                          label: Text(s.communitySendComment),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SocialFeedback(),
                                  const SocialProfileHint(),
                                  const SizedBox(height: 24),
                                  if (page.comments.isEmpty)
                                    Text(s.communityNoComments),
                                  for (final c in page.comments)
                                    Card(
                                      child: Padding(
                                        padding: const EdgeInsets.all(16),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.stretch,
                                          children: [
                                            InkWell(
                                              onTap: () => context.push(
                                                '/people/${c.author.username}',
                                              ),
                                              child: Row(
                                                children: [
                                                  CommunityAvatar(
                                                    path: c.author.avatarPath,
                                                  ),
                                                  const SizedBox(width: 12),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Text(
                                                          c.author.displayName,
                                                          style:
                                                              Theme.of(context)
                                                                  .textTheme
                                                                  .titleSmall,
                                                        ),
                                                        Text(
                                                          '@${c.author.username}',
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(height: 12),
                                            Text(c.content),
                                            const SizedBox(height: 8),
                                            Text(
                                              DateFormat.yMd('es_ES')
                                                  .add_Hm()
                                                  .format(
                                                    c.createdAt.toLocal(),
                                                  ),
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodySmall,
                                            ),
                                            Align(
                                              alignment: Alignment.centerRight,
                                              child: c.authorId == actor
                                                  ? TextButton.icon(
                                                      key: ValueKey(
                                                        'delete-comment-${c.id}',
                                                      ),
                                                      onPressed: action.busy
                                                          ? null
                                                          : () async {
                                                              if (await recipeConfirm(
                                                                    context,
                                                                    title: s
                                                                        .communityDeleteComment,
                                                                    message: s
                                                                        .communityDeleteCommentInfo,
                                                                    action: s
                                                                        .communityDeleteComment,
                                                                  ) &&
                                                                  mounted &&
                                                                  ref.read(
                                                                        recipeActorProvider,
                                                                      ) ==
                                                                      actor) {
                                                                await ref
                                                                    .read(
                                                                      socialActionsProvider
                                                                          .notifier,
                                                                    )
                                                                    .run(
                                                                      (r) => r
                                                                          .deleteComment(
                                                                            c.id,
                                                                          ),
                                                                    );
                                                              }
                                                            },
                                                      icon: const Icon(
                                                        Icons.delete_outline,
                                                      ),
                                                      label: Text(
                                                        s.communityDeleteComment,
                                                      ),
                                                    )
                                                  : TextButton.icon(
                                                      onPressed: action.busy
                                                          ? null
                                                          : () => showReport(
                                                              context,
                                                              ref,
                                                              ReportTarget
                                                                  .comment,
                                                              c.id,
                                                            ),
                                                      icon: const Icon(
                                                        Icons.flag_outlined,
                                                      ),
                                                      label: Text(
                                                        s.communityReport,
                                                      ),
                                                    ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  if (page.moreFailure != null)
                                    Text(communityError(s, page.moreFailure!)),
                                  if (page.cursor != null)
                                    OutlinedButton(
                                      onPressed: page.loadingMore
                                          ? null
                                          : () => ref
                                                .read(
                                                  commentsProvider(
                                                    widget.recipeId,
                                                  ).notifier,
                                                )
                                                .loadMore(),
                                      child: Text(
                                        page.loadingMore
                                            ? s.communityLoading
                                            : s.recipeLoadMore,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
              ),
        ),
      ),
    );
  }
}
