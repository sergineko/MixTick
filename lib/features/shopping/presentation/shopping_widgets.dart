import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/localization/generated/app_localizations.dart';
import '../../../core/widgets/access_revalidation.dart';
import '../../recipes/domain/recipe.dart';
import '../../recipes/presentation/recipe_providers.dart';
import '../../recipes/presentation/recipe_widgets.dart';
import '../domain/shopping.dart';
import 'shopping_providers.dart';

String shoppingError(AppLocalizations s, Object error) =>
    switch (error is ShoppingFailure
    ? error.code
    : ShoppingFailureCode.unexpected) {
      ShoppingFailureCode.network => s.shopNetwork,
      ShoppingFailureCode.forbidden => s.shopForbidden,
      ShoppingFailureCode.conflict => s.shopConflict,
      ShoppingFailureCode.invalid => s.shopInvalid,
      ShoppingFailureCode.quota => s.communityQuota,
      ShoppingFailureCode.unexpected => s.recipeUnexpected,
    };
String itemAmount(ShoppingItem item) => [
  if (item.quantity != null) recipeNumber(item.quantity!),
  if (item.unit != null) item.unit!,
].join(' ');

enum ShoppingEditorKind { list, item, invite }

class ShoppingEditor extends ConsumerStatefulWidget {
  const ShoppingEditor({required this.kind, this.list, this.item, super.key});
  final ShoppingEditorKind kind;
  final ShoppingList? list;
  final ShoppingItem? item;
  @override
  ConsumerState<ShoppingEditor> createState() => _ShoppingEditorState();
}

class _ShoppingEditorState extends ConsumerState<ShoppingEditor> {
  late final name = TextEditingController(
    text:
        widget.item?.name ??
        (widget.kind == ShoppingEditorKind.list ? widget.list?.title : null),
  );
  late final quantity = TextEditingController(
    text: widget.item?.quantity == null
        ? ''
        : recipeNumber(widget.item!.quantity!),
  );
  late final unit = TextEditingController(text: widget.item?.unit ?? '');
  late final actor = ref.read(recipeActorProvider);
  final request = newRecipeRequestId();
  ShoppingItem? baseline;
  ShoppingList? listBaseline;
  Object? failure;
  bool busy = false, conflict = false, uncertain = false;
  bool closeIfForbidden(Object error) {
    if (!mounted ||
        error is! ShoppingFailure ||
        error.code != ShoppingFailureCode.forbidden) {
      return false;
    }
    name.clear();
    quantity.clear();
    unit.clear();
    Navigator.of(context).pop(false);
    return true;
  }

  Future<void> revalidate() async {
    if (busy || widget.list == null) return;
    try {
      final snapshot = await ref
          .read(shoppingRepositoryProvider)!
          .read(widget.list!.id);
      if (baseline != null &&
          !snapshot.items.any((i) => i.id == baseline!.id)) {
        closeIfForbidden(const ShoppingFailure(ShoppingFailureCode.forbidden));
      }
    } catch (error) {
      closeIfForbidden(error);
    }
  }

  @override
  void initState() {
    super.initState();
    baseline = widget.item;
    listBaseline = widget.list;
  }

  @override
  void dispose() {
    name.dispose();
    quantity.dispose();
    unit.dispose();
    super.dispose();
  }

  Future<void> reload() async {
    final s = AppLocalizations.of(context);
    if (!await recipeConfirm(
          context,
          title: s.shopReload,
          message: s.shopDiscardDraft,
          action: s.shopReload,
        ) ||
        !mounted) {
      return;
    }
    setState(() => busy = true);
    try {
      final actual = await ref
          .read(shoppingRepositoryProvider)!
          .read(widget.list!.id);
      if (!mounted || actor != ref.read(recipeActorProvider)) return;
      listBaseline = actual.list;
      if (baseline != null) {
        baseline = actual.items.where((i) => i.id == baseline!.id).firstOrNull;
        if (baseline == null) {
          throw const ShoppingFailure(ShoppingFailureCode.forbidden);
        }
        name.text = baseline!.name;
        quantity.text = baseline!.quantity == null
            ? ''
            : recipeNumber(baseline!.quantity!);
        unit.text = baseline!.unit ?? '';
      } else {
        name.text = actual.list.title;
      }
      setState(() {
        conflict = false;
        failure = null;
        busy = false;
      });
    } catch (error) {
      if (closeIfForbidden(error)) return;
      if (mounted) {
        setState(() {
          failure = error;
          busy = false;
        });
      }
    }
  }

  Future<void> save() async {
    if (busy || conflict) return;
    final repo = ref.read(shoppingRepositoryProvider);
    if (repo == null) return;
    final raw = quantity.text.trim();
    final amount = raw.isEmpty
        ? null
        : double.tryParse(raw.replaceAll(',', '.'));
    final draft = ShoppingDraft(
      name.text,
      quantity: amount,
      unit: unit.text.trim().isEmpty ? null : unit.text.trim(),
      ingredientId: baseline?.ingredientId,
    );
    final valid = widget.kind == ShoppingEditorKind.item
        ? draft.valid && (raw.isEmpty || amount != null)
        : widget.kind == ShoppingEditorKind.invite
        ? RegExp(r'^[a-zA-Z0-9_]{3,30}$').hasMatch(name.text.trim())
        : name.text.trim().runes.isNotEmpty &&
              name.text.trim().runes.length <= 120;
    if (!valid) {
      setState(
        () => failure = const ShoppingFailure(ShoppingFailureCode.invalid),
      );
      return;
    }
    setState(() {
      busy = true;
      failure = null;
    });
    try {
      if (widget.kind == ShoppingEditorKind.list) {
        if (listBaseline == null) {
          await repo.createList(name.text, request);
        } else {
          await repo.rename(listBaseline!, name.text);
        }
      } else if (widget.kind == ShoppingEditorKind.invite) {
        await repo.invite(widget.list!.id, name.text);
      } else if (baseline == null) {
        await repo.add(widget.list!.id, draft, request);
      } else {
        await repo.edit(baseline!, draft);
      }
      if (!mounted || actor != ref.read(recipeActorProvider)) return;
      ref.invalidate(shoppingOverviewProvider);
      if (widget.list != null) {
        ref.invalidate(shoppingDetailProvider(widget.list!.id));
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (closeIfForbidden(error)) return;
      if (mounted && actor == ref.read(recipeActorProvider)) {
        setState(() {
          busy = false;
          failure = error;
          conflict =
              error is ShoppingFailure &&
              error.code == ShoppingFailureCode.conflict &&
              (baseline != null ||
                  widget.kind == ShoppingEditorKind.list &&
                      listBaseline != null);
          uncertain =
              error is ShoppingFailure &&
              error.code == ShoppingFailureCode.network &&
              ((widget.kind == ShoppingEditorKind.item && baseline == null) ||
                  (widget.kind == ShoppingEditorKind.list &&
                      listBaseline == null));
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    ref.listen(recipeActorProvider, (_, next) {
      if (next != actor && mounted) Navigator.of(context).pop(false);
    });
    final title = widget.kind == ShoppingEditorKind.list
        ? (widget.list == null ? s.shopCreate : s.shopRename)
        : widget.kind == ShoppingEditorKind.invite
        ? s.shopInvite
        : widget.item == null
        ? s.shopAdd
        : s.shopEdit;
    return AccessRevalidation(
      onRevalidate: revalidate,
      child: AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                key: const ValueKey('shop-editor-name'),
                controller: name,
                readOnly: busy || uncertain,
                maxLength: widget.kind == ShoppingEditorKind.item
                    ? 80
                    : widget.kind == ShoppingEditorKind.invite
                    ? 30
                    : 120,
                decoration: InputDecoration(
                  labelText: widget.kind == ShoppingEditorKind.list
                      ? s.shopTitle
                      : widget.kind == ShoppingEditorKind.invite
                      ? s.username
                      : s.shopProduct,
                ),
              ),
              if (widget.kind == ShoppingEditorKind.item) ...[
                TextField(
                  key: const ValueKey('shop-editor-quantity'),
                  controller: quantity,
                  readOnly: busy || uncertain,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(labelText: s.recipeQuantity),
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const ValueKey('shop-editor-unit'),
                  controller: unit,
                  readOnly: busy || uncertain,
                  maxLength: 30,
                  decoration: InputDecoration(labelText: s.recipeUnit),
                ),
              ],
              if (busy) const LinearProgressIndicator(),
              if (failure != null)
                Semantics(
                  liveRegion: true,
                  child: Text(
                    shoppingError(s, failure!),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              if (uncertain) Text(s.shopSameRequest),
              if (conflict)
                TextButton(
                  onPressed: busy ? null : reload,
                  child: Text(s.shopReload),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: busy ? null : () => Navigator.of(context).pop(false),
            child: Text(s.recipeCancel),
          ),
          FilledButton(
            key: const ValueKey('shop-editor-save'),
            onPressed: busy || conflict ? null : save,
            child: Text(uncertain ? s.retry : s.shopSave),
          ),
        ],
      ),
    );
  }
}

Future<bool> showShoppingEditor(
  BuildContext context, {
  required ShoppingEditorKind kind,
  ShoppingList? list,
  ShoppingItem? item,
}) async =>
    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ShoppingEditor(kind: kind, list: list, item: item),
    ) ??
    false;
