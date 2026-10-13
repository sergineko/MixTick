import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/localization/generated/app_localizations.dart';
import '../../../core/widgets/app_states.dart';
import '../../auth/presentation/session_scope.dart';
import '../../profile/presentation/profile_providers.dart';
import '../../community/presentation/community_browse.dart';
import '../domain/recipe.dart';
import 'recipe_providers.dart';
import 'recipe_widgets.dart';

class RecipesPage extends StatelessWidget {
  const RecipesPage({super.key});
  @override
  Widget build(BuildContext context) =>
      const SessionScope(child: _RecipesBody());
}

class _RecipesBody extends ConsumerStatefulWidget {
  const _RecipesBody();
  @override
  ConsumerState<_RecipesBody> createState() => _RecipesBodyState();
}

class _RecipesBodyState extends ConsumerState<_RecipesBody> {
  final search = TextEditingController();
  Timer? debounce;
  bool saved = false;
  @override
  void dispose() {
    debounce?.cancel();
    search.dispose();
    super.dispose();
  }

  void filter({
    String? category,
    RecipeVisibility? visibility,
    bool clearCategory = false,
    bool clearVisibility = false,
  }) {
    final current = ref.read(recipeFilterProvider);
    ref
        .read(recipeFilterProvider.notifier)
        .set(
          RecipeFilter(
            search: search.text,
            category: clearCategory ? null : category ?? current.category,
            visibility: clearVisibility
                ? null
                : visibility ?? current.visibility,
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    final current = ref.watch(recipeFilterProvider);
    final configured = ref.watch(recipeRepositoryProvider) != null;
    final profile = ref.watch(ownProfileProvider);
    if (saved) {
      return CommunityBrowse(
        saved: true,
        header: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SegmentedButton<bool>(
              segments: [
                ButtonSegment(
                  value: false,
                  label: Text(s.recipeCreatedSection),
                  icon: const Icon(Icons.edit_outlined),
                ),
                ButtonSegment(
                  value: true,
                  label: Text(s.communitySavedTab),
                  icon: const Icon(Icons.bookmark_border),
                ),
              ],
              selected: const {true},
              onSelectionChanged: (_) => setState(() => saved = false),
            ),
            const SizedBox(height: 24),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(recipeCategoriesProvider);
        final _ = await ref.refresh(mineRecipesProvider.future);
      },
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Semantics(
            header: true,
            child: Text(
              s.recipesTitle,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ),
          const SizedBox(height: 8),
          Text(s.recipesPrivacy),
          const SizedBox(height: 24),
          SegmentedButton<bool>(
            segments: [
              ButtonSegment(
                value: false,
                label: Text(s.recipeCreatedSection),
                icon: const Icon(Icons.edit_outlined),
              ),
              ButtonSegment(
                value: true,
                label: Text(s.communitySavedTab),
                icon: const Icon(Icons.bookmark_border),
              ),
            ],
            selected: const {false},
            onSelectionChanged: (_) => setState(() => saved = true),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            key: const ValueKey('create-recipe'),
            onPressed: !configured ? null : () => context.push('/recipes/new'),
            icon: const Icon(Icons.add),
            label: Text(s.recipeCreate),
          ),
          const SizedBox(height: 24),
          if (configured && profile.hasValue && profile.value == null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.recipeNeedsProfile),
                    TextButton(
                      onPressed: () => context.push('/profile/edit'),
                      child: Text(s.editProfile),
                    ),
                  ],
                ),
              ),
            ),
          Text(
            s.recipeCreatedSection,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          TextField(
            key: const ValueKey('recipe-search'),
            controller: search,
            decoration: InputDecoration(
              labelText: s.recipeSearch,
              prefixIcon: const Icon(Icons.search),
              border: const OutlineInputBorder(),
            ),
            onChanged: (_) {
              debounce?.cancel();
              debounce = Timer(
                const Duration(milliseconds: 350),
                () => filter(),
              );
            },
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 320),
                child: DropdownButtonFormField<RecipeVisibility>(
                  key: ValueKey('visibility-${current.visibility}'),
                  initialValue: current.visibility,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: s.recipeVisibility,
                    border: const OutlineInputBorder(),
                  ),
                  items: [
                    DropdownMenuItem(
                      value: null,
                      child: Text(s.recipeAllVisibility),
                    ),
                    ...RecipeVisibility.values.map(
                      (v) => DropdownMenuItem(
                        value: v,
                        child: Text(
                          v == RecipeVisibility.private
                              ? s.recipePrivate
                              : s.recipePublic,
                        ),
                      ),
                    ),
                  ],
                  onChanged: (v) =>
                      filter(visibility: v, clearVisibility: v == null),
                ),
              ),
              ref
                  .watch(recipeCategoriesProvider)
                  .when(
                    loading: () => const SizedBox.shrink(),
                    error: (error, _) => TextButton(
                      onPressed: () => ref.invalidate(recipeCategoriesProvider),
                      child: Text(s.recipeRetryCategories),
                    ),
                    data: (categories) => ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 320),
                      child: DropdownButtonFormField<String>(
                        key: ValueKey('category-${current.category}'),
                        initialValue: categories.contains(current.category)
                            ? current.category
                            : null,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: s.recipeCategory,
                          border: const OutlineInputBorder(),
                        ),
                        items: [
                          DropdownMenuItem(
                            value: null,
                            child: Text(s.recipeAllCategories),
                          ),
                          ...categories.map(
                            (v) => DropdownMenuItem(value: v, child: Text(v)),
                          ),
                        ],
                        onChanged: (v) =>
                            filter(category: v, clearCategory: v == null),
                      ),
                    ),
                  ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            s.recipeOrderRecent,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 20),
          if (!configured)
            AppEmptyState(
              title: s.recipeBackendMissing,
              message: s.recipeBackendMissingHint,
              icon: Icons.cloud_off_outlined,
            )
          else
            ref
                .watch(mineRecipesProvider)
                .when(
                  skipLoadingOnRefresh: false,
                  loading: () => SizedBox(
                    height: 260,
                    child: AppLoadingState(label: s.recipeLoading),
                  ),
                  error: (error, _) => AppErrorState(
                    message: recipeError(s, error),
                    actionLabel: s.retry,
                    onAction: () => ref.invalidate(mineRecipesProvider),
                  ),
                  data: (page) => Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (page.recipes.isEmpty)
                        AppEmptyState(
                          title: s.recipeEmpty,
                          message: s.recipeEmptyHint,
                          icon: Icons.menu_book_outlined,
                        ),
                      ...page.recipes.map(
                        (r) => RecipeCard(
                          recipe: r,
                          onOpen: () => context.push('/recipes/${r.id}'),
                        ),
                      ),
                      if (page.moreFailure != null)
                        Text(
                          recipeError(s, page.moreFailure!),
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      if (page.cursor != null)
                        OutlinedButton(
                          onPressed: page.loadingMore
                              ? null
                              : () => ref
                                    .read(mineRecipesProvider.notifier)
                                    .loadMore(),
                          child: Text(
                            page.loadingMore
                                ? s.recipeLoading
                                : s.recipeLoadMore,
                          ),
                        ),
                    ],
                  ),
                ),
          const SizedBox(height: 28),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainer,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.bookmark_border),
                const SizedBox(height: 12),
                Text(
                  s.recipeSavedSection,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  key: const ValueKey('open-saved-recipes'),
                  onPressed: () => setState(() => saved = true),
                  icon: const Icon(Icons.bookmark_border),
                  label: Text(s.communitySavedOpen),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
