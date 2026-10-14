import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/localization/generated/app_localizations.dart';
import '../../../core/widgets/access_revalidation.dart';
import '../../recipes/domain/recipe.dart';
import '../../recipes/presentation/recipe_providers.dart';
import '../../recipes/presentation/recipe_widgets.dart';
import '../domain/shopping.dart';
import 'shopping_providers.dart';
import 'shopping_widgets.dart';

class ShoppingDetailPage extends ConsumerStatefulWidget {
  const ShoppingDetailPage({required this.id, super.key});
  final String id;
  @override
  ConsumerState<ShoppingDetailPage> createState() => _ShoppingDetailPageState();
}

class _ShoppingDetailPageState extends ConsumerState<ShoppingDetailPage> {
  final input = TextEditingController(), focus = FocusNode();
  String request = newRecipeRequestId(), requestText = '';
  bool bought = false;
  @override
  void dispose() {
    input.dispose();
    focus.dispose();
    super.dispose();
  }

  ShoppingController get controller =>
      ref.read(shoppingDetailProvider(widget.id).notifier);
  Future<void> refresh() => controller.refresh();
  Future<void> add() async {
    final raw = input.text.trim();
    if (raw.isEmpty) return;
    if (raw != requestText) {
      request = newRecipeRequestId();
      requestText = raw;
    }
    final success = await controller.perform((repo) async {
      await repo.add(widget.id, ShoppingDraft(raw), request);
    });
    if (mounted && success && input.text.trim() == raw) {
      input.clear();
      requestText = '';
    }
    if (mounted && !focus.hasFocus) focus.requestFocus();
  }

  Future<void> exitList(ShoppingList list, bool owner) async {
    final s = AppLocalizations.of(context);
    if (!await recipeConfirm(
          context,
          title: owner ? s.shopDeleteList : s.shopLeave,
          message: owner ? s.shopDeleteInfo : s.shopLeaveInfo,
          action: owner ? s.shopDeleteList : s.shopLeave,
        ) ||
        !mounted) {
      return;
    }
    try {
      final repo = ref.read(shoppingRepositoryProvider)!;
      if (owner) {
        await repo.deleteList(list);
      } else {
        await repo.leave(list.id);
      }
      ref.invalidate(shoppingOverviewProvider);
      if (mounted) context.go('/shopping');
    } catch (error) {
      if (!mounted) return;
      await refresh();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(shoppingError(s, error))));
      }
    }
  }

  Widget members(ShoppingSnapshot snapshot, ShoppingView view, bool owner) {
    final s = AppLocalizations.of(context), list = snapshot.list;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(height: 40),
        Text(s.shopMembers, style: Theme.of(context).textTheme.titleLarge),
        Text(owner ? s.shopOwner : s.shopOwnerOther),
        for (final member in snapshot.members)
          ListTile(
            title: Text(
              member.username == null ? s.shopAccount : '@${member.username}',
            ),
            trailing: owner
                ? IconButton(
                    tooltip: s.shopRevoke,
                    onPressed: view.busy
                        ? null
                        : () async {
                            if (await recipeConfirm(
                                  context,
                                  title: s.shopRevoke,
                                  message: s.shopRevokeInfo,
                                  action: s.shopRevoke,
                                ) &&
                                mounted) {
                              await controller.perform(
                                (repo) => repo.revoke(list.id, member.id),
                              );
                            }
                          },
                    icon: const Icon(Icons.person_remove_outlined),
                  )
                : null,
          ),
        if (owner) ...[
          for (final inv in snapshot.invitations)
            ListTile(
              title: Text(
                inv.username == null ? s.shopAccount : '@${inv.username}',
              ),
              subtitle: Text(s.shopInvitationPending),
              trailing: IconButton(
                tooltip: s.shopRevoke,
                onPressed: view.busy
                    ? null
                    : () => controller.perform(
                        (repo) => repo.revoke(list.id, inv.inviteeId),
                      ),
                icon: const Icon(Icons.cancel_outlined),
              ),
            ),
          OutlinedButton.icon(
            key: const ValueKey('shop-invite'),
            onPressed: view.busy
                ? null
                : () => showShoppingEditor(
                    context,
                    kind: ShoppingEditorKind.invite,
                    list: list,
                  ),
            icon: const Icon(Icons.person_add_outlined),
            label: Text(s.shopInvite),
          ),
          TextButton(
            key: const ValueKey('shop-rename-list'),
            onPressed: view.busy
                ? null
                : () => showShoppingEditor(
                    context,
                    kind: ShoppingEditorKind.list,
                    list: list,
                  ),
            child: Text(s.shopRename),
          ),
        ],
        TextButton(
          key: ValueKey(owner ? 'shop-delete-list' : 'shop-leave'),
          onPressed: view.busy ? null : () => exitList(list, owner),
          child: Text(owner ? s.shopDeleteList : s.shopLeave),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context),
        actor = ref.watch(recipeActorProvider);
    final active = ModalRoute.isCurrentOf(context) ?? true;
    final async = active
        ? ref.watch(shoppingDetailProvider(widget.id))
        : const AsyncData<ShoppingView>(ShoppingView());
    final view = async.value,
        snapshot = async.isLoading || async.hasError ? null : view?.snapshot;
    final list = snapshot?.list, owner = list?.ownerId == actor;
    final items =
        snapshot?.items.where((i) => i.purchased == bought).toList() ?? [];
    final failure = async.error ?? view?.failure;
    return AccessRevalidation(
      onRevalidate: refresh,
      child: Scaffold(
        appBar: AppBar(
          title: Text(list?.title ?? s.shoppingTitle),
          leading: BackButton(
            onPressed: () =>
                context.canPop() ? context.pop() : context.go('/shopping'),
          ),
          actions: [
            IconButton(
              tooltip: s.shopReload,
              onPressed: view?.busy == true ? null : refresh,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: SafeArea(
          child: RefreshIndicator(
            onRefresh: refresh,
            child: ListView.builder(
              key: const ValueKey('shopping-items'),
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: items.length + 2,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (async.isLoading)
                        const Center(child: CircularProgressIndicator()),
                      if (failure != null)
                        Semantics(
                          liveRegion: true,
                          child: Text(
                            shoppingError(s, failure),
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                      if (list != null) ...[
                        Wrap(
                          spacing: 12,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Chip(
                              avatar: Icon(
                                snapshot!.members.isNotEmpty || !owner
                                    ? Icons.group_outlined
                                    : Icons.person_outline,
                                size: 18,
                              ),
                              label: Text(
                                owner
                                    ? (snapshot.members.isEmpty
                                          ? s.shopOwn
                                          : s.shopOwnShared)
                                    : s.shopMember,
                              ),
                            ),
                            Text(
                              view!.refreshing
                                  ? s.shopChecking
                                  : switch (view.signal) {
                                      ShoppingSignal.connected => s.shopSynced,
                                      ShoppingSignal.connecting =>
                                        s.shopConnecting,
                                      _ => s.shopDisconnected,
                                    },
                            ),
                          ],
                        ),
                        if (view.busy || view.refreshing)
                          const LinearProgressIndicator(),
                        const SizedBox(height: 16),
                        TextField(
                          key: const ValueKey('shop-quick-input'),
                          controller: input,
                          focusNode: focus,
                          maxLength: 80,
                          onSubmitted: view.busy ? null : (_) => add(),
                          decoration: InputDecoration(
                            labelText: s.shopQuick,
                            hintText: s.shopHousehold,
                          ),
                        ),
                        Wrap(
                          spacing: 12,
                          children: [
                            FilledButton.icon(
                              key: const ValueKey('shop-quick-add'),
                              onPressed: view.busy ? null : add,
                              icon: const Icon(Icons.add),
                              label: Text(s.shopAdd),
                            ),
                            TextButton(
                              onPressed: view.busy
                                  ? null
                                  : () => showShoppingEditor(
                                      context,
                                      kind: ShoppingEditorKind.item,
                                      list: list,
                                    ),
                              child: Text(s.shopWithAmount),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 12,
                          runSpacing: 8,
                          children: [
                            ChoiceChip(
                              key: const ValueKey('shop-pending'),
                              label: Text(s.shopPending),
                              selected: !bought,
                              onSelected: (_) => setState(() => bought = false),
                            ),
                            ChoiceChip(
                              key: const ValueKey('shop-bought'),
                              label: Text(s.shopBought),
                              selected: bought,
                              onSelected: (_) => setState(() => bought = true),
                            ),
                          ],
                        ),
                      ],
                    ],
                  );
                }
                if (index <= items.length) {
                  final item = items[index - 1];
                  return Card(
                    child: Row(
                      children: [
                        Semantics(
                          label: item.purchased
                              ? s.shopMarkPending
                              : s.shopMarkBought,
                          child: Checkbox(
                            key: ValueKey('shop-check-${item.id}'),
                            value: item.purchased,
                            onChanged: view?.busy == true
                                ? null
                                : (_) => controller.perform(
                                    (repo) => repo.toggle(item),
                                    toggleId: item.id,
                                  ),
                          ),
                        ),
                        Expanded(
                          child: InkWell(
                            key: ValueKey('shop-edit-${item.id}'),
                            onTap: view?.busy == true
                                ? null
                                : () => showShoppingEditor(
                                    context,
                                    kind: ShoppingEditorKind.item,
                                    list: list,
                                    item: item,
                                  ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.name,
                                    style: TextStyle(
                                      decoration: item.purchased
                                          ? TextDecoration.lineThrough
                                          : null,
                                    ),
                                  ),
                                  if (itemAmount(item).isNotEmpty)
                                    Text(itemAmount(item)),
                                ],
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          key: ValueKey('shop-delete-${item.id}'),
                          tooltip: s.shopRemove,
                          onPressed: view?.busy == true
                              ? null
                              : () async {
                                  if (await recipeConfirm(
                                        context,
                                        title: s.shopRemove,
                                        message: s.shopRemoveInfo,
                                        action: s.shopRemove,
                                      ) &&
                                      mounted) {
                                    await controller.perform(
                                      (repo) => repo.remove(item),
                                    );
                                  }
                                },
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ],
                    ),
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (list == null && !async.isLoading)
                      TextButton(
                        onPressed: () =>
                            ref.invalidate(shoppingDetailProvider(widget.id)),
                        child: Text(s.retry),
                      ),
                    if (list != null) ...[
                      if (items.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(bought ? s.shopNoBought : s.shopNoItems),
                        ),
                      members(snapshot!, view!, owner),
                    ],
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
