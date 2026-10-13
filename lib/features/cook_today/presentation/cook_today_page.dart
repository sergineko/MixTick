import 'package:flutter/material.dart';

import '../../../app/localization/generated/app_localizations.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/access_revalidation.dart';
import '../../auth/presentation/session_scope.dart';
import '../../community/presentation/community_providers.dart';
import '../../recipes/domain/recipe.dart';
import '../../recipes/presentation/recipe_providers.dart';
import '../../recipes/presentation/recipe_widgets.dart';
import '../domain/matching.dart';
import 'matching_providers.dart';

class CookTodayPage extends StatelessWidget {
  const CookTodayPage({super.key});
  @override
  Widget build(BuildContext context) =>
      const SessionScope(child: _CookTodayScreen());
}

class _CookTodayScreen extends ConsumerStatefulWidget {
  const _CookTodayScreen();
  @override
  ConsumerState<_CookTodayScreen> createState() => _CookTodayScreenState();
}

class _CookTodayScreenState extends ConsumerState<_CookTodayScreen> {
  final input = TextEditingController(), scroll = ScrollController();
  final focus = FocusNode();
  final selected = <SelectedIngredient>[];
  MatchingMode mode = MatchingMode.exact;
  String? message;
  bool adding = false;
  bool? active;
  MatchingQuery get query => MatchingQuery(selected, mode);
  @override
  void initState() {
    super.initState();
    scroll.addListener(loadMore);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final current = TickerMode.valuesOf(context).enabled;
    if (current && active == false) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) refresh();
      });
    }
    active = current;
  }

  @override
  void dispose() {
    input.dispose();
    scroll.dispose();
    focus.dispose();
    super.dispose();
  }

  Future<void> refresh() async {
    if (!mounted || !TickerMode.valuesOf(context).enabled) return;
    ref.invalidate(recipePhotoProvider);
    if (selected.isEmpty) return;
    try {
      final _ = await ref.refresh(matchingPagesProvider(query).future);
    } catch (_) {
      /* Fresh error is rendered; stale rows hidden. */
    }
  }

  void loadMore() {
    if (!scroll.hasClients || scroll.position.extentAfter > 420) return;
    final page = ref.read(matchingPagesProvider(query));
    if (!page.isLoading && page.value?.moreFailure == null) {
      ref.read(matchingPagesProvider(query).notifier).loadMore();
    }
  }

  Future<void> add(String name) async {
    if (adding) return;
    final s = AppLocalizations.of(context);
    final repo = ref.read(recipeRepositoryProvider),
        actor = ref.read(recipeActorProvider);
    if (repo == null || actor == null) return;
    final raw = name.trim();
    final originalText = input.text;
    if (raw.isEmpty || raw.runes.length > 80) {
      setState(() => message = s.matchInputInvalid);
      return;
    }
    if (selected.length >= 50) {
      setState(() => message = s.matchSelectionLimit);
      return;
    }
    setState(() {
      adding = true;
      message = null;
    });
    try {
      // Free-text fallback also checks the authoritative alias RPC first.
      final canonical = await repo.resolveIngredient(raw);
      if (!mounted || actor != ref.read(recipeActorProvider)) return;
      final item = SelectedIngredient(
        name: canonical?.name ?? raw,
        id: canonical?.id,
      );
      setState(() {
        if (selected.any((i) => i.key == item.key)) {
          message = s.matchDuplicate;
        } else {
          selected.add(item);
        }
        adding = false;
        if (input.text == originalText) input.clear();
      });
      if (!focus.hasFocus) {
        focus.requestFocus();
      }
    } catch (error) {
      if (mounted && actor == ref.read(recipeActorProvider)) {
        setState(() {
          adding = false;
          message = recipeError(s, error);
        });
      }
    }
  }

  Future<void> open(Recipe recipe) async {
    focus.unfocus();
    ref.invalidate(recipeDetailProvider(recipe.id));
    ref.invalidate(socialEntryProvider(recipe.id));
    if (recipe.photoPath != null) {
      ref.invalidate(recipePhotoProvider(recipe.photoPath!));
    }
    await context.push('/recipes/${recipe.id}');
    if (mounted) await refresh();
  }

  Widget modeButton(MatchingMode value, String label) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: OutlinedButton(
      key: ValueKey('matching-${value.name}'),
      style: OutlinedButton.styleFrom(
        backgroundColor: mode == value
            ? Theme.of(context).colorScheme.secondaryContainer
            : null,
      ),
      onPressed: () {
        focus.unfocus();
        setState(() => mode = value);
      },
      child: Row(
        children: [
          Icon(
            mode == value
                ? Icons.radio_button_checked
                : Icons.radio_button_unchecked,
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(label)),
        ],
      ),
    ),
  );
  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context), theme = Theme.of(context);
    final configured = ref.watch(matchingRepositoryProvider) != null;
    final catalog = configured
        ? ref.watch(ingredientCatalogProvider)
        : const AsyncData<List<CatalogIngredient>>([]);
    final current = query;
    final page = TickerMode.valuesOf(context).enabled
        ? ref.watch(matchingPagesProvider(current))
        : const AsyncData<MatchingPage>(MatchingPage([]));
    final matches = page.isLoading || page.hasError
        ? <RecipeMatch>[]
        : page.value?.matches ?? [];
    final term = input.text.trim();
    final suggestions =
        !catalog.isLoading && !catalog.hasError && term.isNotEmpty
        ? (catalog.value ?? <CatalogIngredient>[])
              .where((i) => i.matches(term))
              .take(6)
              .toList()
        : <CatalogIngredient>[];
    Widget framed(Widget child) => Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: child,
      ),
    );
    Widget status(String text, {VoidCallback? retry}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          Semantics(
            liveRegion: true,
            child: Text(text, textAlign: TextAlign.center),
          ),
          if (retry != null) TextButton(onPressed: retry, child: Text(s.retry)),
        ],
      ),
    );
    return AccessRevalidation(
      onRevalidate: refresh,
      child: RefreshIndicator(
        onRefresh: refresh,
        child: ListView.builder(
          key: const ValueKey('matching-list'),
          controller: scroll,
          physics: const AlwaysScrollableScrollPhysics(),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.all(20),
          itemCount: matches.length + 2,
          itemBuilder: (context, index) {
            if (index == 0) {
              return framed(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Semantics(
                      header: true,
                      child: Text(
                        s.cookTodayTitle,
                        style: theme.textTheme.headlineMedium,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(s.cookTodayDescription),
                    const SizedBox(height: 20),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Wrap(
                              alignment: WrapAlignment.spaceBetween,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(
                                  s.matchSelected(selected.length),
                                  style: theme.textTheme.titleMedium,
                                ),
                                if (selected.isNotEmpty)
                                  TextButton(
                                    key: const ValueKey('matching-clear'),
                                    onPressed: adding
                                        ? null
                                        : () {
                                            setState(() {
                                              selected.clear();
                                              message = null;
                                            });
                                          },
                                    child: Text(s.matchClear),
                                  ),
                              ],
                            ),
                            if (selected.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: selected
                                      .map(
                                        (i) => InputChip(
                                          key: ValueKey('selected-${i.key}'),
                                          label: Text(i.name),
                                          deleteButtonTooltipMessage: s
                                              .matchRemove(i.name),
                                          onDeleted: adding
                                              ? null
                                              : () {
                                                  setState(() {
                                                    selected.remove(i);
                                                    message = null;
                                                  });
                                                },
                                        ),
                                      )
                                      .toList(),
                                ),
                              ),
                            TextField(
                              key: const ValueKey('matching-input'),
                              controller: input,
                              focusNode: focus,
                              enabled: configured,
                              maxLength: 80,
                              textInputAction: TextInputAction.done,
                              onChanged: (_) => setState(() => message = null),
                              onSubmitted: add,
                              decoration: InputDecoration(
                                labelText: s.matchIngredientSearch,
                                hintText: s.matchIngredientHint,
                                prefixIcon: const Icon(Icons.search),
                              ),
                            ),
                            if (adding)
                              LinearProgressIndicator(
                                semanticsLabel: s.matchResolving,
                              ),
                            if (catalog.isLoading && configured)
                              Text(s.matchCatalogLoading),
                            if (catalog.hasError && configured)
                              status(
                                recipeError(s, catalog.error!),
                                retry: () =>
                                    ref.invalidate(ingredientCatalogProvider),
                              ),
                            for (final i in suggestions)
                              ListTile(
                                key: ValueKey('suggestion-${i.id}'),
                                contentPadding: EdgeInsets.zero,
                                leading: const Icon(Icons.add_circle_outline),
                                title: Text(i.name),
                                onTap: adding ? null : () => add(i.name),
                              ),
                            if (term.isNotEmpty && configured) ...[
                              TextButton.icon(
                                key: const ValueKey('matching-add'),
                                onPressed: adding ? null : () => add(term),
                                icon: const Icon(Icons.add),
                                label: Text(s.matchAddName),
                              ),
                              Text(
                                s.matchExactNameHint,
                                style: theme.textTheme.bodySmall,
                              ),
                            ],
                            if (message != null)
                              Semantics(
                                liveRegion: true,
                                child: Text(
                                  message!,
                                  style: TextStyle(
                                    color: theme.colorScheme.error,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    modeButton(MatchingMode.exact, s.matchExactMode),
                    modeButton(MatchingMode.near, s.matchNearMode),
                    Text(s.cookTodayNotice, style: theme.textTheme.bodySmall),
                    const SizedBox(height: 24),
                    Semantics(
                      header: true,
                      child: Text(
                        s.matchResults,
                        style: theme.textTheme.titleLarge,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              );
            }
            if (index <= matches.length) {
              return framed(
                MatchingCard(
                  match: matches[index - 1],
                  onOpen: () => open(matches[index - 1].recipe),
                ),
              );
            }
            if (!configured) return framed(status(s.matchNoBackend));
            if (selected.isEmpty) return framed(status(s.matchInitial));
            if (page.isLoading) {
              return framed(
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                ),
              );
            }
            if (page.hasError) {
              return framed(
                status(matchingError(s, page.error!), retry: refresh),
              );
            }
            if (matches.isEmpty) return framed(status(s.matchEmpty));
            final data = page.value!;
            return framed(
              Column(
                children: [
                  if (data.moreFailure != null)
                    status(matchingError(s, data.moreFailure!)),
                  if (data.cursor != null)
                    TextButton(
                      key: const ValueKey('matching-more'),
                      onPressed: data.loadingMore
                          ? null
                          : () => ref
                                .read(matchingPagesProvider(current).notifier)
                                .loadMore(),
                      child: Text(
                        data.loadingMore ? s.matchLoading : s.matchMore,
                      ),
                    ),
                  const SizedBox(height: 24),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

String matchingError(AppLocalizations s, Object error) =>
    switch (error is MatchingFailure
    ? error.code
    : MatchingFailureCode.unexpected) {
      MatchingFailureCode.network => s.recipeNetworkError,
      MatchingFailureCode.forbidden => s.recipeForbidden,
      MatchingFailureCode.invalid => s.matchInputInvalid,
      MatchingFailureCode.unexpected => s.recipeUnexpected,
    };

class MatchingCard extends StatelessWidget {
  const MatchingCard({required this.match, required this.onOpen, super.key});
  final RecipeMatch match;
  final VoidCallback onOpen;
  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context), theme = Theme.of(context);
    final recipe = match.recipe;
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.only(bottom: 20),
      child: InkWell(
        key: ValueKey('match-open-${recipe.id}'),
        onTap: onOpen,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            RecipePhoto(path: recipe.photoPath, height: 180),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(recipe.title, style: theme.textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text(
                    '${match.author.displayName} · @${match.author.username}',
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 16,
                    runSpacing: 8,
                    children: [
                      Text(recipe.category),
                      Text(
                        recipe.totalMinutes == null
                            ? s.matchTimeUnknown
                            : '${recipe.totalMinutes} ${s.recipeMinutes}',
                      ),
                      if (recipe.visibility == RecipeVisibility.private)
                        RecipePrivacyBadge(recipe.visibility),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        match.missing == 0
                            ? Icons.check_circle_outline
                            : Icons.shopping_basket_outlined,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          s.matchStatus(match.missing),
                          style: theme.textTheme.titleMedium,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    s.matchCounts(match.matched, match.required, match.missing),
                  ),
                  if (match.missing > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        s.matchMissingNames(
                          match.missingIngredients
                              .map((i) => i.ingredient.name)
                              .toSet()
                              .join(', '),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
