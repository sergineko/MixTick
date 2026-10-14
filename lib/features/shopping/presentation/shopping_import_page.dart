import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/localization/generated/app_localizations.dart';
import '../../../core/widgets/access_revalidation.dart';
import '../../cook_today/domain/matching.dart';
import '../../recipes/domain/recipe.dart';
import '../../recipes/presentation/recipe_providers.dart';
import '../../recipes/presentation/recipe_widgets.dart';
import '../domain/shopping.dart';
import 'shopping_providers.dart';
import 'shopping_widgets.dart';

class ShoppingImportPage extends ConsumerStatefulWidget {
  const ShoppingImportPage({required this.recipeId, this.missing, super.key});
  final String recipeId;
  final MissingIngredientsTransfer? missing;
  @override
  ConsumerState<ShoppingImportPage> createState() => _ShoppingImportPageState();
}

class _ShoppingImportPageState extends ConsumerState<ShoppingImportPage> {
  String? destination;
  String request = newRecipeRequestId(), signature = '';
  final selected = <String>{};
  Object? failure;
  bool busy = false;
  int? imported;
  ({String list, ShoppingImportPreview preview, List<MissingIngredient> lines})?
  attempt;
  Future<void> refresh() async {
    if (busy || imported != null) return;
    ref.invalidate(shoppingOverviewProvider);
    ref.invalidate(shoppingPreviewProvider(widget.recipeId));
  }

  Future<void> confirm(
    ShoppingImportPreview preview,
    List<MissingIngredient> lines,
  ) async {
    if (busy || destination == null || lines.isEmpty) return;
    final actor = ref.read(recipeActorProvider),
        repo = ref.read(shoppingRepositoryProvider);
    if (repo == null || actor == null) return;
    final operation =
        attempt ??
        (
          list: destination!,
          preview: preview,
          lines: List<MissingIngredient>.unmodifiable(lines),
        );
    attempt = operation;
    setState(() {
      busy = true;
      failure = null;
    });
    try {
      final ids = await repo.importIngredients(
        operation.list,
        operation.preview,
        operation.lines,
        request,
        missingOnly: widget.missing != null,
      );
      if (!mounted || actor != ref.read(recipeActorProvider)) return;
      ref.invalidate(shoppingOverviewProvider);
      setState(() {
        busy = false;
        imported = ids.length;
      });
    } catch (error) {
      if (!mounted || actor != ref.read(recipeActorProvider)) return;
      setState(() {
        busy = false;
        failure = error;
      });
      // A transport failure may follow a committed transaction: retain UUID and
      // immutable payload until that exact operation has been reconciled.
      if (error is! ShoppingFailure ||
          error.code != ShoppingFailureCode.network) {
        attempt = null;
        if (error is ShoppingFailure &&
            error.code == ShoppingFailureCode.conflict) {
          request = newRecipeRequestId();
          ref.invalidate(shoppingPreviewProvider(widget.recipeId));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    final overview = ref.watch(shoppingOverviewProvider),
        previewState = ref.watch(shoppingPreviewProvider(widget.recipeId));
    final preview = previewState.isLoading || previewState.hasError
        ? null
        : previewState.value;
    final overviewData = overview.isLoading || overview.hasError
        ? null
        : overview.value;
    final stale =
        preview != null &&
        widget.missing != null &&
        !preview.accepts(widget.missing!);
    final available = preview == null
        ? <MissingIngredient>[]
        : widget.missing == null
        ? preview.lines
        : stale
        ? <MissingIngredient>[]
        : preview.lines
              .where(
                (line) => widget.missing!.lines.any(
                  (old) => old.lineId == line.lineId,
                ),
              )
              .toList();
    if (preview != null && attempt == null) {
      final next =
          '${preview.version}:${available.map((i) => i.lineId).join(',')}';
      if (signature != next) {
        signature = next;
        selected.clear();
        selected.addAll(available.map((i) => i.lineId));
      }
    }
    final lines = available.where((i) => selected.contains(i.lineId)).toList();
    final destinations = overviewData?.lists ?? <ShoppingList>[];
    final validDestination = destinations.any((l) => l.id == destination);
    return AccessRevalidation(
      onRevalidate: refresh,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            widget.missing == null ? s.shopImport : s.shopMissingImport,
          ),
          actions: [
            IconButton(
              tooltip: s.shopReload,
              onPressed: busy ? null : refresh,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(s.shopImportPrivacy),
              const SizedBox(height: 16),
              if (busy || overview.isLoading || previewState.isLoading)
                const LinearProgressIndicator(),
              if (failure != null)
                Semantics(
                  liveRegion: true,
                  child: Text(shoppingError(s, failure!)),
                ),
              if (overview.hasError) Text(shoppingError(s, overview.error!)),
              if (previewState.hasError)
                Text(shoppingError(s, previewState.error!)),
              if (overview.hasError || previewState.hasError)
                TextButton(onPressed: refresh, child: Text(s.retry)),
              if (imported != null) ...[
                Text(
                  s.shopImported(imported!),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                FilledButton(
                  key: const ValueKey('shop-open-destination'),
                  onPressed: () =>
                      context.go('/shopping/list/${attempt!.list}'),
                  child: Text(s.shopOpenList),
                ),
              ] else if (attempt != null &&
                  !busy &&
                  failure is ShoppingFailure &&
                  (failure as ShoppingFailure).code ==
                      ShoppingFailureCode.network) ...[
                Text(s.shopSameRequest),
                FilledButton(
                  key: const ValueKey('shop-import-retry'),
                  onPressed: () => confirm(attempt!.preview, attempt!.lines),
                  child: Text(s.retry),
                ),
              ] else if (preview != null && overviewData != null) ...[
                Text(
                  preview.title,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                Text(
                  '${recipeNumber(preview.servings)} ${s.recipeServings.toLowerCase()}',
                ),
                Text(s.shopOriginalAmounts),
                const SizedBox(height: 20),
                if (stale) ...[
                  Text(s.shopRecipeChanged),
                  FilledButton(
                    key: const ValueKey('shop-recalculate'),
                    onPressed: () => context.go('/cook-today'),
                    child: Text(s.shopRecalculate),
                  ),
                ] else ...[
                  if (destinations.isEmpty) ...[
                    Text(s.shopChooseCreate),
                    FilledButton(
                      onPressed: () => showShoppingEditor(
                        context,
                        kind: ShoppingEditorKind.list,
                      ),
                      child: Text(s.shopCreate),
                    ),
                  ] else
                    DropdownButtonFormField<String>(
                      key: const ValueKey('shop-destination'),
                      initialValue: validDestination ? destination : null,
                      isExpanded: true,
                      decoration: InputDecoration(labelText: s.shopDestination),
                      items: destinations
                          .map(
                            (l) => DropdownMenuItem(
                              value: l.id,
                              child: Text(
                                l.title,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: busy
                          ? null
                          : (id) => setState(() => destination = id),
                    ),
                  const SizedBox(height: 16),
                  for (final line in available)
                    CheckboxListTile(
                      key: ValueKey('shop-import-line-${line.lineId}'),
                      contentPadding: EdgeInsets.zero,
                      value: selected.contains(line.lineId),
                      onChanged: busy
                          ? null
                          : (value) => setState(() {
                              if (value == true) {
                                selected.add(line.lineId);
                              } else {
                                selected.remove(line.lineId);
                              }
                            }),
                      title: Text(line.ingredient.name),
                      subtitle: Text(
                        [
                          if (line.ingredient.quantity != null)
                            recipeNumber(line.ingredient.quantity!),
                          if (line.ingredient.unit != null)
                            line.ingredient.unit!,
                          if (line.ingredient.optional) s.recipeOptional,
                        ].join(' · '),
                      ),
                    ),
                  FilledButton.icon(
                    key: const ValueKey('shop-import-confirm'),
                    onPressed: busy || !validDestination || lines.isEmpty
                        ? null
                        : () => confirm(preview, lines),
                    icon: const Icon(Icons.add_shopping_cart),
                    label: Text(s.shopConfirmImport),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}
