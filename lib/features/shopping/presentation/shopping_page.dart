import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/localization/generated/app_localizations.dart';
import '../../../core/widgets/access_revalidation.dart';
import '../../auth/presentation/session_scope.dart';
import '../../recipes/presentation/recipe_providers.dart';
import '../domain/shopping.dart';
import 'shopping_providers.dart';
import 'shopping_widgets.dart';

class ShoppingPage extends StatelessWidget {
  const ShoppingPage({super.key});
  @override
  Widget build(BuildContext context) =>
      const SessionScope(child: _ShoppingOverviewScreen());
}

class _ShoppingOverviewScreen extends ConsumerStatefulWidget {
  const _ShoppingOverviewScreen();
  @override
  ConsumerState<_ShoppingOverviewScreen> createState() =>
      _ShoppingOverviewScreenState();
}

class _ShoppingOverviewScreenState
    extends ConsumerState<_ShoppingOverviewScreen> {
  Object? failure;
  bool busy = false;
  Future<void> refresh() async {
    if (!TickerMode.valuesOf(context).enabled) return;
    try {
      final _ = await ref.refresh(shoppingOverviewProvider.future);
    } catch (_) {
      /* Fresh provider error is visible. */
    }
  }

  Future<void> respond(ShoppingInvitation invitation, bool accept) async {
    if (busy) return;
    final actor = ref.read(recipeActorProvider);
    setState(() {
      busy = true;
      failure = null;
    });
    try {
      await ref.read(shoppingRepositoryProvider)!.respond(invitation, accept);
    } catch (error) {
      if (mounted && actor == ref.read(recipeActorProvider)) {
        setState(() => failure = error);
      }
    }
    if (mounted && actor == ref.read(recipeActorProvider)) {
      setState(() => busy = false);
      await refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context),
        actor = ref.watch(recipeActorProvider);
    final configured = ref.watch(shoppingRepositoryProvider) != null;
    final page = TickerMode.valuesOf(context).enabled
        ? ref.watch(shoppingOverviewProvider)
        : const AsyncData(ShoppingOverview([], []));
    final data = page.isLoading || page.hasError ? null : page.value;
    return AccessRevalidation(
      onRevalidate: refresh,
      child: RefreshIndicator(
        onRefresh: refresh,
        child: ListView(
          key: const ValueKey('shopping-overview'),
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              s.shoppingTitle,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 12),
            Text(s.shopIntro),
            const SizedBox(height: 20),
            FilledButton.icon(
              key: const ValueKey('shop-create-list'),
              onPressed: configured && !busy
                  ? () => showShoppingEditor(
                      context,
                      kind: ShoppingEditorKind.list,
                    )
                  : null,
              icon: const Icon(Icons.add),
              label: Text(s.shopCreate),
            ),
            if (!configured)
              Padding(
                padding: const EdgeInsets.all(20),
                child: Text(s.shopNoBackend),
              ),
            if (page.isLoading)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              ),
            if (page.hasError) ...[
              Text(shoppingError(s, page.error!)),
              TextButton(onPressed: refresh, child: Text(s.retry)),
            ],
            if (failure != null)
              Semantics(
                liveRegion: true,
                child: Text(shoppingError(s, failure!)),
              ),
            if (data != null) ...[
              if (data.invitations.isNotEmpty) ...[
                const SizedBox(height: 24),
                Text(
                  s.shopInvitations,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                for (final inv in data.invitations)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            inv.title ?? s.shoppingTitle,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          Text('@${inv.username ?? s.shopAccount}'),
                          Wrap(
                            spacing: 12,
                            children: [
                              FilledButton(
                                key: ValueKey('shop-accept-${inv.id}'),
                                onPressed: busy
                                    ? null
                                    : () => respond(inv, true),
                                child: Text(s.shopAccept),
                              ),
                              TextButton(
                                onPressed: busy
                                    ? null
                                    : () => respond(inv, false),
                                child: Text(s.shopReject),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
              const SizedBox(height: 24),
              Text(s.shopLists, style: Theme.of(context).textTheme.titleLarge),
              if (data.lists.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text(s.shopEmpty),
                ),
              for (final list in data.lists)
                Card(
                  child: ListTile(
                    key: ValueKey('shop-list-${list.id}'),
                    leading: Icon(
                      list.shared || list.ownerId != actor
                          ? Icons.group_outlined
                          : Icons.checklist,
                    ),
                    title: Text(list.title),
                    subtitle: Text(
                      list.ownerId == actor
                          ? (list.shared ? s.shopOwnShared : s.shopOwn)
                          : s.shopMember,
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () async {
                      await context.push('/shopping/list/${list.id}');
                      if (mounted) await refresh();
                    },
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
