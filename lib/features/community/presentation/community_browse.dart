import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/localization/generated/app_localizations.dart';
import '../../../core/widgets/app_states.dart';
import '../../../core/network/supabase_bootstrap.dart';
import '../../profile/presentation/profile_providers.dart';
import '../../recipes/presentation/recipe_providers.dart';
import '../domain/community.dart';
import 'community_providers.dart';
import 'community_widgets.dart';

/// Same public projection powers feed, saved references and author recipes.
class CommunityBrowse extends ConsumerStatefulWidget {
  const CommunityBrowse({
    this.saved = false,
    this.author,
    this.header,
    this.showFilters = true,
    super.key,
  });
  final bool saved, showFilters;
  final String? author;
  final Widget? header;
  @override
  ConsumerState<CommunityBrowse> createState() => _CommunityBrowseState();
}

class _CommunityBrowseState extends ConsumerState<CommunityBrowse>
    with WidgetsBindingObserver {
  final search = TextEditingController(), scroll = ScrollController();
  Timer? debounce, poll;
  String term = '';
  String? category;
  bool? active;
  CommunityQuery get query => CommunityQuery(
    search: term,
    category: category,
    author: widget.author,
    saved: widget.saved,
  );
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    scroll.addListener(loadMore);
    if (ref.read(backendProvider).client != null) {
      poll = Timer.periodic(const Duration(seconds: 30), (_) {
        if (mounted &&
            TickerMode.valuesOf(context).enabled &&
            ModalRoute.of(context)?.isCurrent == true) {
          refresh();
        }
      });
    }
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
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    scroll.dispose();
    search.dispose();
    debounce?.cancel();
    poll?.cancel();
    super.dispose();
  }

  Future<void> refresh() async {
    ref.invalidate(recipePhotoProvider);
    ref.invalidate(avatarProvider);
    ref.invalidate(communityCategoriesProvider);
    try {
      final _ = await ref.refresh(communityPagesProvider(query).future);
    } catch (_) {
      /* Async error is shown, stale rows are hidden. */
    }
  }

  void loadMore() {
    if (!scroll.hasClients || scroll.position.extentAfter > 420) return;
    final page = ref.read(communityPagesProvider(query));
    if (!page.isLoading && page.value?.moreFailure == null) {
      ref.read(communityPagesProvider(query).notifier).loadMore();
    }
  }

  void changeSearch(String value) {
    debounce?.cancel();
    debounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted) {
        setState(() => term = value.trim());
        if (scroll.hasClients) scroll.jumpTo(0);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    final configured = ref.watch(communityRepositoryProvider) != null;
    final page = ref.watch(communityPagesProvider(query));
    final entries = page.isLoading || page.hasError
        ? <CommunityEntry>[]
        : page.value?.entries ?? [];
    Widget framed(Widget child) => Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: child,
      ),
    );
    return RefreshIndicator(
      onRefresh: refresh,
      child: ListView.builder(
        key: ValueKey('community-list-${widget.saved}-${widget.author}'),
        controller: scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        itemCount: entries.length + 2,
        itemBuilder: (context, index) {
          if (index == 0) {
            return framed(
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (widget.header != null) widget.header!,
                  if (widget.author == null) ...[
                    Semantics(
                      header: true,
                      child: Text(
                        widget.saved ? s.recipeSavedSection : s.communityTitle,
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.saved
                          ? s.communitySavedInfo
                          : s.communityChronological,
                    ),
                    const SizedBox(height: 20),
                  ],
                  if (widget.showFilters) ...[
                    TextField(
                      key: const ValueKey('community-search'),
                      controller: search,
                      maxLength: 120,
                      decoration: InputDecoration(
                        labelText: s.communitySearch,
                        prefixIcon: const Icon(Icons.search),
                        border: const OutlineInputBorder(),
                        counterText: '',
                      ),
                      onChanged: changeSearch,
                    ),
                    const SizedBox(height: 12),
                    ref
                        .watch(communityCategoriesProvider)
                        .when(
                          skipLoadingOnRefresh: false,
                          loading: () => const SizedBox.shrink(),
                          error: (_, _) => TextButton(
                            onPressed: () =>
                                ref.invalidate(communityCategoriesProvider),
                            child: Text(s.recipeRetryCategories),
                          ),
                          data: (categories) => DropdownButtonFormField<String>(
                            key: ValueKey('community-category-$category'),
                            initialValue: categories.contains(category)
                                ? category
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
                                (v) =>
                                    DropdownMenuItem(value: v, child: Text(v)),
                              ),
                            ],
                            onChanged: (value) {
                              setState(() => category = value);
                              if (scroll.hasClients) scroll.jumpTo(0);
                            },
                          ),
                        ),
                    const SizedBox(height: 8),
                    Text(
                      s.communitySearchCoverage,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                  const SocialProfileHint(),
                  const SocialFeedback(),
                  const SizedBox(height: 20),
                ],
              ),
            );
          }
          if (index <= entries.length) {
            final entry = entries[index - 1];
            return framed(
              CommunityRecipeCard(
                entry: entry,
                onOpen: () async {
                  ref.invalidate(recipeDetailProvider(entry.recipe.id));
                  ref.invalidate(socialEntryProvider(entry.recipe.id));
                  ref.invalidate(recipePhotoProvider);
                  await context.push('/recipes/${entry.recipe.id}');
                  if (mounted) refresh();
                },
              ),
            );
          }
          if (!configured) {
            return framed(
              AppEmptyState(
                title: s.recipeBackendMissing,
                message: s.recipeBackendMissingHint,
                icon: Icons.cloud_off_outlined,
              ),
            );
          }
          if (page.isLoading) {
            return framed(
              SizedBox(
                height: 200,
                child: AppLoadingState(label: s.communityLoading),
              ),
            );
          }
          if (page.hasError) {
            return framed(
              AppErrorState(
                message: communityError(s, page.error!),
                actionLabel: s.retry,
                onAction: refresh,
              ),
            );
          }
          final data = page.value;
          if (entries.isEmpty) {
            return framed(
              AppEmptyState(
                title: s.communityEmpty,
                message: widget.saved
                    ? s.communitySavedEmpty
                    : s.communityEmptyInfo,
                icon: widget.saved
                    ? Icons.bookmark_border
                    : Icons.restaurant_outlined,
              ),
            );
          }
          return framed(
            Column(
              children: [
                if (data?.moreFailure != null)
                  Text(
                    communityError(s, data!.moreFailure!),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                if (data?.cursor != null)
                  OutlinedButton(
                    onPressed: data!.loadingMore
                        ? null
                        : () => ref
                              .read(communityPagesProvider(query).notifier)
                              .loadMore(),
                    child: Text(
                      data.loadingMore ? s.communityLoading : s.recipeLoadMore,
                    ),
                  ),
                const SizedBox(height: 32),
              ],
            ),
          );
        },
      ),
    );
  }
}
