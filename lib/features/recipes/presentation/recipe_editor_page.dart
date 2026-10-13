import 'dart:typed_data';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/localization/generated/app_localizations.dart';
import '../../../core/widgets/app_states.dart';
import '../../profile/data/avatar_processor.dart';
import '../../profile/presentation/profile_providers.dart';
import '../domain/recipe.dart';
import '../domain/recipe_repository.dart';
import 'ingredient_editor.dart';
import 'recipe_providers.dart';
import 'recipe_widgets.dart';

class RecipeEditorPage extends ConsumerStatefulWidget {
  const RecipeEditorPage({this.recipeId, super.key});
  final String? recipeId;
  @override
  ConsumerState<RecipeEditorPage> createState() => _RecipeEditorPageState();
}

class _StepInput {
  _StepInput([String text = '']) : text = TextEditingController(text: text);
  final TextEditingController text;
  final key = UniqueKey();
}

class _RecipeEditorPageState extends ConsumerState<RecipeEditorPage> {
  final form = GlobalKey<FormState>();
  final title = TextEditingController(),
      description = TextEditingController(),
      category = TextEditingController(),
      servings = TextEditingController(text: '2'),
      prep = TextEditingController(),
      cook = TextEditingController();
  final ingredients = <RecipeIngredient>[];
  final steps = <_StepInput>[];
  final requestId = newRecipeRequestId();
  Recipe? baseline;
  bool loaded = false,
      dirty = false,
      allowPop = false,
      picking = false,
      removePhoto = false,
      invalid = false,
      conflicted = false,
      photoPending = false;
  Uint8List? photo;
  Object? pickerError;
  void clearPreview() {
    final previous = photo;
    photo = null;
    if (previous != null) unawaited(MemoryImage(previous).evict());
  }

  @override
  void initState() {
    super.initState();
    if (widget.recipeId == null) {
      loaded = true;
      steps.add(_StepInput());
    }
  }

  @override
  void dispose() {
    for (final c in [title, description, category, servings, prep, cook]) {
      c.dispose();
    }
    for (final step in steps) {
      step.text.dispose();
    }
    clearPreview();
    super.dispose();
  }

  void populate(Recipe recipe) {
    baseline = recipe;
    title.text = recipe.title;
    description.text = recipe.description ?? '';
    category.text = recipe.category;
    servings.text = recipeNumber(recipe.servings);
    prep.text = recipe.prepMinutes?.toString() ?? '';
    cook.text = recipe.cookMinutes?.toString() ?? '';
    ingredients
      ..clear()
      ..addAll(recipe.ingredients);
    for (final step in steps) {
      step.text.dispose();
    }
    steps
      ..clear()
      ..addAll(recipe.steps.map(_StepInput.new));
    clearPreview();
    removePhoto = false;
    photoPending = false;
    conflicted = false;
    loaded = true;
    dirty = false;
  }

  Future<void> ingredient([int? index]) async {
    final actor = ref.read(recipeActorProvider);
    if (actor == null) return;
    final previous = index == null ? null : ingredients[index];
    final others = [
      for (var i = 0; i < ingredients.length; i++)
        if (i != index) ingredients[i],
    ];
    final result = await showDialog<RecipeIngredient>(
      context: context,
      builder: (_) => IngredientEditor(
        actorId: actor,
        previous: previous,
        existing: others,
      ),
    );
    if (!mounted || result == null) return;
    setState(() {
      if (index == null) {
        ingredients.add(result);
      } else {
        ingredients[index] = result;
      }
      dirty = true;
      invalid = false;
    });
  }

  Future<void> save() async {
    final s = AppLocalizations.of(context);
    if (!form.currentState!.validate()) return;
    final draft = RecipeDraft(
      title: title.text,
      description: description.text,
      category: category.text,
      servings: RecipeValidation.parseDecimal(servings.text) ?? 0,
      prepMinutes: prep.text.trim().isEmpty
          ? null
          : int.tryParse(prep.text.trim()),
      cookMinutes: cook.text.trim().isEmpty
          ? null
          : int.tryParse(cook.text.trim()),
      ingredients: List.of(ingredients),
      steps: steps.map((i) => i.text.text).toList(),
    );
    if (!draft.valid) {
      setState(() => invalid = true);
      return;
    }
    final outcome = await ref
        .read(recipeActionsProvider.notifier)
        .save(
          draft,
          previous: baseline,
          requestId: requestId,
          photo: photo,
          removePhoto: removePhoto,
        );
    if (!mounted) return;
    if (outcome.recipe != null) baseline = outcome.recipe;
    if (outcome.success) {
      setState(() {
        dirty = false;
        allowPop = true;
        clearPreview();
      });
      context.replace('/recipes/${outcome.recipe!.id}');
    } else {
      setState(() {
        photoPending = outcome.photoPending;
        conflicted = outcome.failure == RecipeFailureCode.conflict;
      });
      if (outcome.failure == null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(s.recipeUnexpected)));
      }
    }
  }

  Future<void> reload() async {
    final s = AppLocalizations.of(context);
    if (!await recipeConfirm(
          context,
          title: s.recipeReload,
          message: s.recipeReloadWarning,
          action: s.recipeReload,
        ) ||
        !mounted) {
      return;
    }
    final id = baseline?.id ?? widget.recipeId;
    if (id == null) {
      setState(() => allowPop = true);
      context.go('/recipes');
      return;
    }
    final actor = ref.read(recipeActorProvider);
    setState(() => loaded = false);
    try {
      final actual = await ref.refresh(recipeDetailProvider(id).future);
      if (mounted && ref.read(recipeActorProvider) == actor && actual != null) {
        setState(() => populate(actual));
        ref.read(recipeActionsProvider.notifier).clearFailure();
      }
    } catch (_) {
      /* The provider renders its actual error and retry action. */
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    final action = ref.watch(recipeActionsProvider);
    final busy = action.busy || picking;
    final id = baseline?.id ?? widget.recipeId;
    final record = id == null
        ? const AsyncData<Recipe?>(null)
        : ref.watch(recipeDetailProvider(id));
    if (!loaded &&
        !record.isLoading &&
        !record.hasError &&
        record.hasValue &&
        record.value != null) {
      populate(record.value!);
    }
    final own = ref.watch(ownProfileProvider);
    final actor = ref.watch(recipeActorProvider);
    final stage = switch (action.stage) {
      RecipeActionStage.uploading => s.recipeUploading,
      RecipeActionStage.linking => s.recipeLinking,
      RecipeActionStage.cancelling => s.recipeCancelling,
      _ => s.recipeSaving,
    };
    Widget field(
      TextEditingController controller,
      String label,
      String key, {
      int? maxLength,
      int minLines = 1,
      int maxLines = 1,
      TextInputType? keyboard,
      String? Function(String?)? validator,
    }) => Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        key: ValueKey(key),
        controller: controller,
        enabled: !busy,
        maxLength: maxLength,
        minLines: minLines,
        maxLines: maxLines,
        keyboardType: keyboard,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        validator: validator,
        onChanged: (_) => setState(() => dirty = true),
      ),
    );
    String? text(String? value, int max) =>
        value == null || value.trim().isEmpty || value.trim().runes.length > max
        ? s.recipeInvalidText
        : null;
    String? time(String? value) {
      if (value == null || value.trim().isEmpty) return null;
      final n = int.tryParse(value.trim());
      return n != null && n >= 0 && n <= 10080 ? null : s.recipeInvalidTime;
    }

    Widget editor() => Form(
      key: form,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RecipePrivacyBadge(baseline?.visibility ?? RecipeVisibility.private),
          Text(
            baseline?.visibility == RecipeVisibility.public
                ? s.recipePublishInfo
                : s.recipesPrivacy,
          ),
          const SizedBox(height: 20),
          ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: photo != null
                ? Image.memory(
                    photo!,
                    height: 240,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    semanticLabel: s.recipePhoto,
                  )
                : RecipePhoto(
                    path: removePhoto ? null : baseline?.photoPath,
                    height: 240,
                  ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                key: const ValueKey('choose-recipe-photo'),
                onPressed: busy
                    ? null
                    : () async {
                        setState(() {
                          picking = true;
                          pickerError = null;
                        });
                        try {
                          final selected = await ref
                              .read(photoPickerProvider)
                              .pick();
                          if (selected != null) {
                            final prepared = await prepareAvatar(selected);
                            if (mounted) {
                              setState(() {
                                clearPreview();
                                photo = prepared;
                                removePhoto = false;
                                dirty = true;
                              });
                            }
                          }
                        } catch (_) {
                          if (mounted) {
                            setState(
                              () => pickerError = const RecipeFailure(
                                RecipeFailureCode.photo,
                              ),
                            );
                          }
                        } finally {
                          if (mounted) setState(() => picking = false);
                        }
                      },
                icon: const Icon(Icons.photo_library_outlined),
                label: Text(s.choosePhoto),
              ),
              if (photo != null || baseline?.photoPath != null)
                TextButton(
                  onPressed: busy
                      ? null
                      : () => setState(() {
                          clearPreview();
                          removePhoto = true;
                          dirty = true;
                        }),
                  child: Text(s.removePhoto),
                ),
            ],
          ),
          if (pickerError != null)
            Text(
              recipeError(s, pickerError!),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          const SizedBox(height: 24),
          RecipeSection(
            title: s.recipeBasics,
            child: Column(
              children: [
                field(
                  title,
                  s.recipeTitle,
                  'recipe-title',
                  maxLength: 120,
                  validator: (v) => text(v, 120),
                ),
                field(
                  description,
                  s.recipeDescription,
                  'recipe-description',
                  maxLength: 4000,
                  minLines: 2,
                  maxLines: 6,
                ),
                field(
                  category,
                  s.recipeCategory,
                  'recipe-category',
                  maxLength: 60,
                  validator: (v) => text(v, 60),
                ),
                field(
                  servings,
                  s.recipeServings,
                  'recipe-servings',
                  keyboard: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  validator: (v) {
                    final n = RecipeValidation.parseDecimal(v ?? '');
                    return n != null && RecipeValidation.decimal(n, 10000, 2)
                        ? null
                        : s.recipeInvalidServings;
                  },
                ),
                field(
                  prep,
                  s.recipePrep,
                  'recipe-prep',
                  keyboard: TextInputType.number,
                  validator: time,
                ),
                field(
                  cook,
                  s.recipeCook,
                  'recipe-cook',
                  keyboard: TextInputType.number,
                  validator: time,
                ),
              ],
            ),
          ),
          RecipeSection(
            title: s.recipeIngredients,
            action: TextButton.icon(
              key: const ValueKey('add-recipe-ingredient'),
              onPressed: busy || ingredients.length >= 100
                  ? null
                  : () => ingredient(),
              icon: const Icon(Icons.add),
              label: Text(s.recipeAddIngredient),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (ingredients.isEmpty) Text(s.recipeAtLeastOneIngredient),
                for (var i = 0; i < ingredients.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ingredients[i].name,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(
                          [
                            if (ingredients[i].quantity != null)
                              recipeNumber(ingredients[i].quantity!),
                            if (ingredients[i].unit != null)
                              ingredients[i].unit!,
                            if (ingredients[i].optional) s.recipeOptional,
                          ].join(' · '),
                        ),
                        Wrap(
                          children: [
                            TextButton.icon(
                              onPressed: busy ? null : () => ingredient(i),
                              icon: const Icon(Icons.edit_outlined),
                              label: Text(s.recipeEditIngredient),
                            ),
                            IconButton(
                              tooltip: s.recipeRemoveIngredient,
                              onPressed: busy
                                  ? null
                                  : () => setState(() {
                                      ingredients.removeAt(i);
                                      dirty = true;
                                    }),
                              icon: const Icon(Icons.close),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          RecipeSection(
            title: s.recipeSteps,
            action: TextButton.icon(
              key: const ValueKey('add-recipe-step'),
              onPressed: busy || steps.length >= 100
                  ? null
                  : () => setState(() {
                      steps.add(_StepInput());
                      dirty = true;
                    }),
              icon: const Icon(Icons.add),
              label: Text(s.recipeAddStep),
            ),
            child: Column(
              children: [
                if (steps.isEmpty) Text(s.recipeAtLeastOneStep),
                for (var i = 0; i < steps.length; i++)
                  Padding(
                    key: steps[i].key,
                    padding: const EdgeInsets.only(bottom: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        field(
                          steps[i].text,
                          '${i + 1}. ${s.recipeStepInstruction}',
                          'recipe-step-$i',
                          minLines: 2,
                          maxLines: 6,
                          maxLength: 4000,
                          validator: (v) => text(v, 4000),
                        ),
                        Wrap(
                          alignment: WrapAlignment.end,
                          children: [
                            IconButton(
                              tooltip: s.recipeStepUp,
                              onPressed: busy || i == 0
                                  ? null
                                  : () => setState(() {
                                      final step = steps.removeAt(i);
                                      steps.insert(i - 1, step);
                                      dirty = true;
                                    }),
                              icon: const Icon(Icons.arrow_upward),
                            ),
                            IconButton(
                              tooltip: s.recipeStepDown,
                              onPressed: busy || i == steps.length - 1
                                  ? null
                                  : () => setState(() {
                                      final step = steps.removeAt(i);
                                      steps.insert(i + 1, step);
                                      dirty = true;
                                    }),
                              icon: const Icon(Icons.arrow_downward),
                            ),
                            IconButton(
                              tooltip: s.recipeRemoveStep,
                              onPressed: busy
                                  ? null
                                  : () => setState(() {
                                      steps.removeAt(i).text.dispose();
                                      dirty = true;
                                    }),
                              icon: const Icon(Icons.delete_outline),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          if (invalid)
            Semantics(
              liveRegion: true,
              child: Text(
                s.recipeInvalid,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          if (photoPending) Text(s.recipeFieldsSaved),
          if (action.failure != null)
            Semantics(
              liveRegion: true,
              child: Text(
                recipeError(s, RecipeFailure(action.failure!)),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          if (conflicted)
            TextButton(
              onPressed: busy ? null : reload,
              child: Text(s.recipeReload),
            ),
          if (busy)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Semantics(
                liveRegion: true,
                child: Column(
                  children: [
                    const LinearProgressIndicator(),
                    const SizedBox(height: 12),
                    Text(stage),
                  ],
                ),
              ),
            ),
          if (action.stage == RecipeActionStage.uploading)
            TextButton(
              onPressed: () =>
                  ref.read(recipeActionsProvider.notifier).cancelPhoto(),
              child: Text(s.recipeCancelUpload),
            ),
          FilledButton(
            key: const ValueKey('save-recipe'),
            onPressed: busy || conflicted ? null : save,
            child: Text(s.recipeSave),
          ),
          const SizedBox(height: 12),
          Text(
            s.recipePhotoLifecycle,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
    return PopScope(
      canPop: allowPop || (!dirty && !busy),
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop || busy) return;
        if (await recipeConfirm(
              context,
              title: s.recipeDiscardTitle,
              message: s.recipeDiscardMessage,
              action: s.recipeDiscard,
            ) &&
            mounted) {
          setState(() => allowPop = true);
          await WidgetsBinding.instance.endOfFrame;
          if (context.mounted) context.pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.recipeId == null ? s.recipeCreate : s.recipeEdit),
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: !loaded
                  ? record.when(
                      skipLoadingOnRefresh: false,
                      loading: () => AppLoadingState(label: s.recipeLoading),
                      error: (error, _) => AppErrorState(
                        message: recipeError(s, error),
                        actionLabel: s.retry,
                        onAction: () =>
                            ref.invalidate(recipeDetailProvider(id!)),
                      ),
                      data: (r) => r == null
                          ? AppEmptyState(title: s.recipeForbidden, message: '')
                          : const SizedBox.shrink(),
                    )
                  : baseline != null && baseline!.authorId != actor
                  ? AppEmptyState(title: s.recipeForbidden, message: '')
                  : own.when(
                      loading: () => AppLoadingState(label: s.loadingProfile),
                      error: (error, _) => AppErrorState(
                        message: s.recipeNetworkError,
                        actionLabel: s.retry,
                        onAction: () => ref.invalidate(ownProfileProvider),
                      ),
                      data: (profile) => profile == null
                          ? AppEmptyState(
                              title: s.recipeNeedsProfile,
                              message: '',
                              footer: FilledButton(
                                onPressed: () => context.push('/profile/edit'),
                                child: Text(s.editProfile),
                              ),
                            )
                          : SingleChildScrollView(
                              padding: const EdgeInsets.all(20),
                              child: editor(),
                            ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
