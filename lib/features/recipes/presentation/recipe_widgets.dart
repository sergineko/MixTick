import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/localization/generated/app_localizations.dart';
import '../domain/recipe.dart';
import '../domain/recipe_repository.dart';
import 'recipe_providers.dart';

String recipeError(AppLocalizations s, Object error) =>
    switch (error is RecipeFailure
    ? error.code
    : RecipeFailureCode.unexpected) {
      RecipeFailureCode.network => s.recipeNetworkError,
      RecipeFailureCode.forbidden => s.recipeForbidden,
      RecipeFailureCode.conflict => s.recipeConflict,
      RecipeFailureCode.invalid => s.recipeInvalid,
      RecipeFailureCode.quota => s.recipeQuota,
      RecipeFailureCode.photo => s.invalidPhoto,
      RecipeFailureCode.cancelled => s.recipePhotoCancelled,
      RecipeFailureCode.unexpected => s.recipeUnexpected,
    };
String recipeNumber(num value) => NumberFormat('0.###', 'es_ES').format(value);

class RecipePrivacyBadge extends StatelessWidget {
  const RecipePrivacyBadge(this.visibility, {super.key});
  final RecipeVisibility visibility;
  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    final private = visibility == RecipeVisibility.private;
    return Chip(
      avatar: Icon(private ? Icons.lock_outline : Icons.public, size: 18),
      label: Text(private ? s.recipePrivate : s.recipePublic),
      visualDensity: VisualDensity.compact,
    );
  }
}

class RecipePhoto extends ConsumerWidget {
  const RecipePhoto({this.path, this.height = 220, super.key});
  final String? path;
  final double height;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppLocalizations.of(context);
    Widget placeholder(IconData icon, String label) => Semantics(
      label: label,
      child: Container(
        height: height,
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        alignment: Alignment.center,
        child: Icon(
          icon,
          size: 48,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
    if (path == null) {
      return placeholder(Icons.restaurant_outlined, s.recipeNoPhoto);
    }
    return ref
        .watch(recipePhotoProvider(path!))
        .when(
          skipLoadingOnRefresh: false,
          loading: () => placeholder(Icons.photo_outlined, s.loadingPhoto),
          error: (_, _) => SizedBox(
            height: height,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.broken_image_outlined),
                Text(s.photoUnavailable),
                TextButton(
                  onPressed: () => ref.invalidate(recipePhotoProvider(path!)),
                  child: Text(s.retry),
                ),
              ],
            ),
          ),
          data: (bytes) => Image.memory(
            bytes,
            height: height,
            width: double.infinity,
            fit: BoxFit.cover,
            semanticLabel: s.recipePhoto,
            gaplessPlayback: false,
          ),
        );
  }
}

class RecipeCard extends StatelessWidget {
  const RecipeCard({required this.recipe, required this.onOpen, super.key});
  final Recipe recipe;
  final VoidCallback onOpen;
  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.only(bottom: 20),
      child: InkWell(
        onTap: onOpen,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            RecipePhoto(path: recipe.photoPath, height: 190),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RecipePrivacyBadge(recipe.visibility),
                  const SizedBox(height: 6),
                  Text(recipe.title, style: theme.textTheme.titleLarge),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 16,
                    runSpacing: 8,
                    children: [
                      Text(recipe.category),
                      if (recipe.totalMinutes != null)
                        Text('${recipe.totalMinutes} ${s.recipeMinutes}'),
                    ],
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

class RecipeSection extends StatelessWidget {
  const RecipeSection({
    required this.title,
    required this.child,
    this.action,
    super.key,
  });
  final String title;
  final Widget child;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 20),
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(title, style: Theme.of(context).textTheme.titleLarge),
          ),
          if (action != null)
            Align(alignment: Alignment.centerLeft, child: action!),
          const SizedBox(height: 16),
          child,
        ],
      ),
    ),
  );
}

Future<bool> recipeConfirm(
  BuildContext context, {
  required String title,
  required String message,
  required String action,
}) async {
  final s = AppLocalizations.of(context);
  return await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: SingleChildScrollView(child: Text(message)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(s.recipeCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(action),
            ),
          ],
        ),
      ) ??
      false;
}
