import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/localization/generated/app_localizations.dart';
import '../domain/recipe.dart';
import 'recipe_widgets.dart';
import 'recipe_providers.dart';

class IngredientEditor extends ConsumerStatefulWidget {
  const IngredientEditor({
    required this.existing,
    required this.actorId,
    this.previous,
    super.key,
  });
  final String actorId;
  final List<RecipeIngredient> existing;
  final RecipeIngredient? previous;
  @override
  ConsumerState<IngredientEditor> createState() => _IngredientEditorState();
}

class _IngredientEditorState extends ConsumerState<IngredientEditor> {
  final form = GlobalKey<FormState>();
  late String name = widget.previous?.name ?? '';
  late final quantity = TextEditingController(
    text: widget.previous?.quantity?.toString() ?? '',
  );
  late final unit = TextEditingController(text: widget.previous?.unit ?? '');
  late bool optional = widget.previous?.optional ?? false;
  bool duplicate = false;
  bool busy = false;
  Object? error;
  @override
  void dispose() {
    quantity.dispose();
    unit.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    if (ref.watch(recipeActorProvider) != widget.actorId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && ModalRoute.of(context)?.isCurrent == true) {
          Navigator.pop(context);
        }
      });
      return const SizedBox.shrink();
    }
    final catalog = ref.watch(ingredientCatalogProvider);
    return AlertDialog(
      title: Text(
        widget.previous == null
            ? s.recipeAddIngredient
            : s.recipeEditIngredient,
      ),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Form(
            key: form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                catalog.when(
                  loading: () => Text(s.recipeCatalogLoading),
                  error: (_, _) => Column(
                    children: [
                      Text(s.recipeCatalogError),
                      TextButton(
                        onPressed: () =>
                            ref.invalidate(ingredientCatalogProvider),
                        child: Text(s.retry),
                      ),
                    ],
                  ),
                  data: (choices) => Autocomplete<CatalogIngredient>(
                    initialValue: TextEditingValue(text: name),
                    displayStringForOption: (i) => i.name,
                    optionsBuilder: (v) => v.text.trim().isEmpty
                        ? const Iterable<CatalogIngredient>.empty()
                        : choices.where((i) => i.matches(v.text)).take(8),
                    onSelected: (i) {
                      name = i.name;
                      setState(() => duplicate = false);
                    },
                    fieldViewBuilder: (context, controller, focus, onSubmit) =>
                        TextFormField(
                          key: const ValueKey('ingredient-name'),
                          controller: controller,
                          enabled: !busy,
                          focusNode: focus,
                          maxLength: 80,
                          decoration: InputDecoration(
                            labelText: s.recipeIngredientName,
                          ),
                          onChanged: (v) {
                            name = v;
                            setState(() => duplicate = false);
                          },
                          validator: (v) =>
                              v == null ||
                                  v.trim().isEmpty ||
                                  v.trim().runes.length > 80
                              ? s.recipeInvalidText
                              : null,
                        ),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const ValueKey('ingredient-quantity'),
                  controller: quantity,
                  enabled: !busy,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(labelText: s.recipeQuantity),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return null;
                    final n = RecipeValidation.parseDecimal(v);
                    return n != null && RecipeValidation.decimal(n, 1000000, 3)
                        ? null
                        : s.recipeInvalidQuantity;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const ValueKey('ingredient-unit'),
                  controller: unit,
                  enabled: !busy,
                  maxLength: 30,
                  decoration: InputDecoration(
                    labelText: s.recipeUnit,
                    helperText: s.recipeUnitHint,
                  ),
                  validator: (v) => v != null && v.trim().runes.length > 30
                      ? s.recipeInvalidText
                      : null,
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: Text(s.recipeOptional),
                  value: optional,
                  onChanged: busy ? null : (v) => setState(() => optional = v),
                ),
                if (duplicate)
                  Text(
                    s.recipeDuplicate,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                if (error != null)
                  Text(
                    recipeError(s, error!),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                Text(
                  s.recipeCustomIngredient,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(s.recipeCancel),
        ),
        FilledButton(
          key: const ValueKey('confirm-ingredient'),
          onPressed: !catalog.hasValue || busy
              ? null
              : () async {
                  if (!form.currentState!.validate()) return;
                  var selected = catalog.value!
                      .where((i) => i.resolves(name))
                      .firstOrNull;
                  setState(() {
                    busy = true;
                    error = null;
                  });
                  try {
                    selected ??= await ref
                        .read(recipeRepositoryProvider)!
                        .resolveIngredient(name);
                  } catch (failure) {
                    if (mounted) {
                      setState(() {
                        busy = false;
                        error = failure;
                      });
                    }
                    return;
                  }
                  if (!mounted ||
                      ref.read(recipeActorProvider) != widget.actorId) {
                    return;
                  }
                  setState(() => busy = false);
                  final result = RecipeIngredient(
                    ingredientId: selected?.id,
                    customName: selected == null ? name.trim() : null,
                    name: selected?.name ?? name.trim(),
                    quantity: quantity.text.trim().isEmpty
                        ? null
                        : RecipeValidation.parseDecimal(quantity.text),
                    unit: unit.text.trim().isEmpty ? null : unit.text.trim(),
                    optional: optional,
                  );
                  if (widget.existing.any((i) => i.key == result.key)) {
                    setState(() => duplicate = true);
                    return;
                  }
                  Navigator.pop(this.context, result);
                },
          child: Text(widget.previous == null ? s.recipeAdd : s.recipeSave),
        ),
      ],
    );
  }
}
