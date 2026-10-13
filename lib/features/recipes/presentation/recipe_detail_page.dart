import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/localization/generated/app_localizations.dart';
import '../../../core/widgets/app_states.dart';
import '../../../core/widgets/access_revalidation.dart';
import '../../community/presentation/community_detail_social.dart';
import '../../community/presentation/community_providers.dart';
import '../domain/recipe.dart';
import '../domain/recipe_repository.dart';
import 'recipe_providers.dart';
import 'recipe_widgets.dart';

class RecipeDetailPage extends ConsumerStatefulWidget {
  const RecipeDetailPage({required this.id, super.key});
  final String id;
  @override
  ConsumerState<RecipeDetailPage> createState() => _RecipeDetailPageState();
}

class _RecipeDetailPageState extends ConsumerState<RecipeDetailPage>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(recipeDetailProvider(widget.id));
      ref.invalidate(recipePhotoProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    final action = ref.watch(recipeActionsProvider);
    final actor = ref.watch(recipeActorProvider);
    return AccessRevalidation(
      onRevalidate: () {
        ref.invalidate(recipeDetailProvider(widget.id));
        ref.invalidate(socialEntryProvider(widget.id));
        ref.invalidate(recipePhotoProvider);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(s.recipeView),
          leading: BackButton(
            onPressed: () =>
                context.canPop() ? context.pop() : context.go('/recipes'),
          ),
          actions: [
            IconButton(
              tooltip: s.recipeReload,
              onPressed: action.busy
                  ? null
                  : () {
                      ref.invalidate(recipeDetailProvider(widget.id));
                      ref.invalidate(socialEntryProvider(widget.id));
                      ref.invalidate(recipePhotoProvider);
                    },
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: SafeArea(
          child: ref
              .watch(recipeDetailProvider(widget.id))
              .when(
                skipLoadingOnRefresh: false,
                loading: () => AppLoadingState(label: s.recipeLoading),
                error: (error, _) => AppErrorState(
                  message: recipeError(s, error),
                  actionLabel: s.retry,
                  onAction: () =>
                      ref.invalidate(recipeDetailProvider(widget.id)),
                ),
                data: (recipe) => recipe == null
                    ? AppEmptyState(title: s.recipeForbidden, message: '')
                    : SingleChildScrollView(
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 720),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (recipe.visibility ==
                                    RecipeVisibility.public)
                                  CommunityDetailGate(
                                    recipeId: recipe.id,
                                    child: RecipeContent(recipe: recipe),
                                  )
                                else
                                  RecipeContent(recipe: recipe),
                                if (recipe.authorId == actor)
                                  Padding(
                                    padding: const EdgeInsets.all(20),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        FilledButton.icon(
                                          key: const ValueKey('edit-recipe'),
                                          onPressed: action.busy
                                              ? null
                                              : () => context.push(
                                                  '/recipes/${recipe.id}/edit',
                                                ),
                                          icon: const Icon(Icons.edit_outlined),
                                          label: Text(s.recipeEdit),
                                        ),
                                        const SizedBox(height: 12),
                                        OutlinedButton.icon(
                                          key: const ValueKey(
                                            'toggle-recipe-visibility',
                                          ),
                                          onPressed: action.busy
                                              ? null
                                              : () async {
                                                  final public =
                                                      recipe.visibility ==
                                                      RecipeVisibility.public;
                                                  if (!await recipeConfirm(
                                                        context,
                                                        title: public
                                                            ? s.recipeMakePrivate
                                                            : s.recipePublish,
                                                        message: public
                                                            ? s.recipePrivateInfo
                                                            : s.recipePublishInfo,
                                                        action: public
                                                            ? s.recipeMakePrivate
                                                            : s.recipePublish,
                                                      ) ||
                                                      !mounted) {
                                                    return;
                                                  }
                                                  await ref
                                                      .read(
                                                        recipeActionsProvider
                                                            .notifier,
                                                      )
                                                      .changeVisibility(
                                                        recipe,
                                                        public
                                                            ? RecipeVisibility
                                                                  .private
                                                            : RecipeVisibility
                                                                  .public,
                                                      );
                                                },
                                          icon: Icon(
                                            recipe.visibility ==
                                                    RecipeVisibility.public
                                                ? Icons.lock_outline
                                                : Icons.public,
                                          ),
                                          label: Text(
                                            recipe.visibility ==
                                                    RecipeVisibility.public
                                                ? s.recipeMakePrivate
                                                : s.recipePublish,
                                          ),
                                        ),
                                        TextButton.icon(
                                          key: const ValueKey('delete-recipe'),
                                          onPressed: action.busy
                                              ? null
                                              : () async {
                                                  if (!await recipeConfirm(
                                                        context,
                                                        title: s.recipeDelete,
                                                        message:
                                                            s.recipeDeleteInfo,
                                                        action: s.recipeDelete,
                                                      ) ||
                                                      !mounted) {
                                                    return;
                                                  }
                                                  if (await ref
                                                          .read(
                                                            recipeActionsProvider
                                                                .notifier,
                                                          )
                                                          .delete(recipe) &&
                                                      context.mounted) {
                                                    context.go('/recipes');
                                                  }
                                                },
                                          icon: const Icon(
                                            Icons.delete_outline,
                                          ),
                                          label: Text(s.recipeDelete),
                                        ),
                                        if (action.busy)
                                          const LinearProgressIndicator(),
                                        if (action.failure != null)
                                          Semantics(
                                            liveRegion: true,
                                            child: Text(
                                              recipeError(
                                                s,
                                                RecipeFailure(action.failure!),
                                              ),
                                              style: TextStyle(
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .error,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
              ),
        ),
      ),
    );
  }
}

/// Shared presentation of an accessible recipe; future modules can reuse it
/// without author actions, shopping, social controls or advanced cooking mode.
class RecipeContent extends StatelessWidget {
  const RecipeContent({required this.recipe, super.key});
  final Recipe recipe;
  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RecipePhoto(path: recipe.photoPath, height: 300),
        Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: RecipePrivacyBadge(recipe.visibility),
              ),
              const SizedBox(height: 12),
              Semantics(
                header: true,
                child: Text(recipe.title, style: theme.textTheme.headlineLarge),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 16,
                runSpacing: 12,
                children: [
                  Chip(label: Text(recipe.category)),
                  Chip(
                    avatar: const Icon(Icons.people_outline, size: 18),
                    label: Text(
                      '${recipeNumber(recipe.servings)} ${s.recipeServings.toLowerCase()}',
                    ),
                  ),
                  if (recipe.totalMinutes != null)
                    Chip(
                      avatar: const Icon(Icons.timer_outlined, size: 18),
                      label: Text('${recipe.totalMinutes} ${s.recipeMinutes}'),
                    ),
                ],
              ),
              if (recipe.description?.isNotEmpty == true)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Text(
                    recipe.description!,
                    style: theme.textTheme.bodyLarge,
                  ),
                ),
              if (recipe.prepMinutes != null)
                Text('${s.recipePrep}: ${recipe.prepMinutes}'),
              if (recipe.cookMinutes != null)
                Text('${s.recipeCook}: ${recipe.cookMinutes}'),
              const SizedBox(height: 24),
              RecipeSection(
                title: s.recipeIngredients,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final i in recipe.ingredients)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(i.name, style: theme.textTheme.titleMedium),
                            Text(
                              [
                                if (i.quantity != null)
                                  recipeNumber(i.quantity!),
                                if (i.unit != null) i.unit!,
                                if (i.optional) s.recipeOptional,
                              ].join(' · '),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              RecipeSection(
                title: s.recipeSteps,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < recipe.steps.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(radius: 18, child: Text('${i + 1}')),
                            const SizedBox(height: 12),
                            Text(
                              recipe.steps[i],
                              style: theme.textTheme.bodyLarge,
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
