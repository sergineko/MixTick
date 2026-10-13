import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/localization/generated/app_localizations.dart';
import '../../profile/presentation/profile_providers.dart';
import '../../recipes/presentation/recipe_providers.dart';
import '../../recipes/presentation/recipe_widgets.dart';
import '../domain/community.dart';
import 'community_providers.dart';

String communityError(AppLocalizations s, Object error) =>
    switch (error is CommunityFailure
    ? error.code
    : CommunityFailureCode.unexpected) {
      CommunityFailureCode.network => s.networkError,
      CommunityFailureCode.forbidden => s.communityUnavailable,
      CommunityFailureCode.invalid => s.communityInvalid,
      CommunityFailureCode.quota => s.communityQuota,
      CommunityFailureCode.conflict => s.communityConflict,
      CommunityFailureCode.unexpected => s.operationError,
    };

class SocialProfileHint extends ConsumerWidget {
  const SocialProfileHint({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppLocalizations.of(context),
        profile = ref.watch(ownProfileProvider);
    if (ref.watch(communityRepositoryProvider) == null ||
        profile.isLoading ||
        profile.value != null) {
      return const SizedBox.shrink();
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(profile.hasError ? s.operationError : s.communityNeedsProfile),
            TextButton(
              onPressed: profile.hasError
                  ? () => ref.invalidate(ownProfileProvider)
                  : () => context.push('/profile/edit'),
              child: Text(profile.hasError ? s.retry : s.editProfile),
            ),
          ],
        ),
      ),
    );
  }
}

class CommunityAvatar extends ConsumerWidget {
  const CommunityAvatar({this.path, super.key});
  final String? path;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppLocalizations.of(context);
    if (path == null) {
      return const CircleAvatar(child: Icon(Icons.person_outline));
    }
    return ref
        .watch(avatarProvider(path!))
        .when(
          skipLoadingOnRefresh: false,
          data: (bytes) => ClipOval(
            child: Image.memory(
              bytes,
              width: 40,
              height: 40,
              fit: BoxFit.cover,
              semanticLabel: s.profilePhoto,
            ),
          ),
          error: (_, _) =>
              const CircleAvatar(child: Icon(Icons.person_outline)),
          loading: () => const SizedBox(
            width: 40,
            height: 40,
            child: Padding(
              padding: EdgeInsets.all(10),
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        );
  }
}

class AuthorLink extends ConsumerWidget {
  const AuthorLink({required this.entry, super.key});
  final CommunityEntry entry;
  @override
  Widget build(BuildContext context, WidgetRef ref) => InkWell(
    borderRadius: BorderRadius.circular(12),
    onTap: () async {
      ref.invalidate(publicProfileProvider(entry.author.username));
      ref.invalidate(socialAuthorProvider(entry.author.username));
      ref.invalidate(avatarProvider);
      await context.push('/people/${entry.author.username}');
      if (context.mounted) {
        ref.invalidate(socialEntryProvider(entry.recipe.id));
        ref.invalidate(communityPagesProvider);
      }
    },
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          CommunityAvatar(path: entry.author.avatarPath),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.author.displayName,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                Text(
                  '@${entry.author.username}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right),
        ],
      ),
    ),
  );
}

class SocialButtons extends ConsumerWidget {
  const SocialButtons({required this.entry, super.key});
  final CommunityEntry entry;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppLocalizations.of(context),
        action = ref.watch(socialActionsProvider);
    final enabled = !action.busy && ref.watch(canParticipateProvider);
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        TextButton.icon(
          key: ValueKey('like-${entry.recipe.id}'),
          onPressed: !enabled
              ? null
              : () => ref
                    .read(socialActionsProvider.notifier)
                    .run((r) => r.like(entry.recipe.id, !entry.liked)),
          icon: Icon(entry.liked ? Icons.favorite : Icons.favorite_border),
          label: Text('${entry.likes} ${s.communityLikes}'),
          style: entry.liked
              ? TextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.primary,
                )
              : null,
        ),
        TextButton.icon(
          key: ValueKey('comments-${entry.recipe.id}'),
          onPressed: () => context.push('/recipes/${entry.recipe.id}/comments'),
          icon: const Icon(Icons.chat_bubble_outline),
          label: Text(s.communityCommentsCount(entry.comments)),
        ),
        if (entry.recipe.authorId != ref.watch(recipeActorProvider))
          TextButton.icon(
            key: ValueKey('save-${entry.recipe.id}'),
            onPressed: !enabled
                ? null
                : () => ref
                      .read(socialActionsProvider.notifier)
                      .run((r) => r.save(entry.recipe.id, !entry.saved)),
            icon: Icon(entry.saved ? Icons.bookmark : Icons.bookmark_border),
            label: Text(entry.saved ? s.communitySaved : s.communitySave),
          ),
      ],
    );
  }
}

class CommunityRecipeCard extends ConsumerWidget {
  const CommunityRecipeCard({
    required this.entry,
    required this.onOpen,
    super.key,
  });
  final CommunityEntry entry;
  final VoidCallback onOpen;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppLocalizations.of(context), theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            key: ValueKey('open-${entry.recipe.id}'),
            onTap: onOpen,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                RecipePhoto(path: entry.recipe.photoPath, height: 210),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.recipe.title,
                        style: theme.textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 16,
                        runSpacing: 8,
                        children: [
                          Text(
                            entry.recipe.category,
                            style: theme.textTheme.labelLarge,
                          ),
                          if (entry.recipe.totalMinutes != null)
                            Text(
                              '${entry.recipe.totalMinutes} ${s.recipeMinutes}',
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: AuthorLink(entry: entry),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
            child: SocialButtons(entry: entry),
          ),
        ],
      ),
    );
  }
}

class SocialFeedback extends ConsumerWidget {
  const SocialFeedback({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppLocalizations.of(context),
        action = ref.watch(socialActionsProvider);
    return Column(
      children: [
        if (action.busy) const LinearProgressIndicator(),
        if (action.failure != null)
          Semantics(
            liveRegion: true,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                communityError(s, CommunityFailure(action.failure!)),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          ),
      ],
    );
  }
}

Future<void> showReport(
  BuildContext context,
  WidgetRef ref,
  ReportTarget target,
  String id,
) async {
  final actor = ref.read(recipeActorProvider);
  if (actor == null) return;
  await showDialog<void>(
    context: context,
    builder: (_) => _ReportDialog(target: target, id: id, actor: actor),
  );
}

class _ReportDialog extends ConsumerStatefulWidget {
  const _ReportDialog({
    required this.target,
    required this.id,
    required this.actor,
  });
  final ReportTarget target;
  final String id, actor;
  @override
  ConsumerState<_ReportDialog> createState() => _ReportDialogState();
}

class _ReportDialogState extends ConsumerState<_ReportDialog> {
  String? reason;
  bool sent = false;
  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context),
        busy = ref.watch(socialActionsProvider).busy;
    if (ref.watch(recipeActorProvider) != widget.actor) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pop();
      });
      return const SizedBox.shrink();
    }
    return AlertDialog(
      title: Text(sent ? s.communityReportSent : s.communityReport),
      content: sent
          ? Text(s.communityReportSentInfo)
          : SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: reason,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: s.communityReportReason,
                    ),
                    items:
                        [
                              s.communityReasonSpam,
                              s.communityReasonAbuse,
                              s.communityReasonDanger,
                              s.communityReasonRights,
                            ]
                            .map(
                              (v) => DropdownMenuItem(value: v, child: Text(v)),
                            )
                            .toList(),
                    onChanged: busy ? null : (v) => setState(() => reason = v),
                  ),
                  const SocialFeedback(),
                ],
              ),
            ),
      actions: [
        TextButton(
          onPressed: busy ? null : () => Navigator.of(context).pop(),
          child: Text(sent ? s.communityClose : s.recipeCancel),
        ),
        if (!sent)
          FilledButton(
            onPressed: busy || reason == null
                ? null
                : () async {
                    final ok = await ref
                        .read(socialActionsProvider.notifier)
                        .run(
                          (r) => r.report(widget.target, widget.id, reason!),
                        );
                    if (mounted &&
                        ref.read(recipeActorProvider) == widget.actor &&
                        ok) {
                      setState(() => sent = true);
                    }
                  },
            child: Text(s.communitySendReport),
          ),
      ],
    );
  }
}
