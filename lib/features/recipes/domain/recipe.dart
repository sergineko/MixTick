import 'dart:math';
import 'dart:convert';

enum RecipeVisibility { private, public }

String newRecipeRequestId() {
  final random = Random.secure();
  final b = List.generate(16, (_) => random.nextInt(256));
  b[6] = (b[6] & 15) | 64;
  b[8] = (b[8] & 63) | 128;
  final h = b.map((v) => v.toRadixString(16).padLeft(2, '0')).join();
  return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
}

String normalizeIngredientText(String value) {
  const accented = 'áàäâéèëêíìïîóòöôúùüûñ';
  const plain = 'aaaaeeeeiiiioooouuuun';
  var result = value.trim().toLowerCase();
  for (var i = 0; i < accented.length; i++) {
    result = result.replaceAll(accented[i], plain[i]);
  }
  return result.replaceAll(RegExp(r'\s+'), ' ');
}

class CatalogIngredient {
  const CatalogIngredient({
    required this.id,
    required this.name,
    this.aliases = const [],
  });
  final String id, name;
  final List<String> aliases;
  bool matches(String query) => [name, ...aliases].any(
    (v) => normalizeIngredientText(v).contains(normalizeIngredientText(query)),
  );
  bool resolves(String query) => [
    name,
    ...aliases,
  ].any((v) => normalizeIngredientText(v) == normalizeIngredientText(query));
}

class RecipeIngredient {
  const RecipeIngredient({
    this.ingredientId,
    this.customName,
    required this.name,
    this.quantity,
    this.unit,
    this.optional = false,
  });
  final String? ingredientId, customName, unit;
  final String name;
  final double? quantity;
  final bool optional;
  String get key =>
      ingredientId ?? 'custom:${normalizeIngredientText(customName ?? name)}';
  Map<String, dynamic> toJson() => {
    'ingredient_id': ingredientId,
    'custom_name': customName?.trim(),
    'quantity': quantity,
    'unit': unit?.trim(),
    'optional': optional,
  };
  factory RecipeIngredient.fromJson(Map<String, dynamic> json) =>
      RecipeIngredient(
        ingredientId: json['ingredient_id'] as String?,
        customName: json['custom_name'] as String?,
        name:
            (json['ingredients'] as Map<String, dynamic>?)?['canonical_name_es']
                as String? ??
            json['custom_name'] as String? ??
            '',
        quantity: (json['quantity'] as num?)?.toDouble(),
        unit: json['unit'] as String?,
        optional: json['optional'] as bool,
      );
}

class RecipeDraft {
  const RecipeDraft({
    required this.title,
    required this.category,
    required this.servings,
    required this.ingredients,
    required this.steps,
    this.description,
    this.prepMinutes,
    this.cookMinutes,
  });
  final String title, category;
  final String? description;
  final double servings;
  final int? prepMinutes, cookMinutes;
  final List<RecipeIngredient> ingredients;
  final List<String> steps;
  bool matches(Recipe recipe) {
    final actual = RecipeDraft(
      title: recipe.title,
      description: recipe.description,
      category: recipe.category,
      servings: recipe.servings,
      prepMinutes: recipe.prepMinutes,
      cookMinutes: recipe.cookMinutes,
      ingredients: recipe.ingredients,
      steps: recipe.steps,
    );
    Object fingerprint(RecipeDraft value) => [
      value.header,
      value.ingredients.map((i) => i.toJson()).toList(),
      value.steps.map((s) => s.trim()).toList(),
    ];
    return jsonEncode(fingerprint(this)) == jsonEncode(fingerprint(actual));
  }

  Map<String, dynamic> get header => {
    'title': title.trim(),
    'description': description?.trim().isEmpty == true
        ? null
        : description?.trim(),
    'category': category.trim(),
    'servings': servings,
    'prep_minutes': prepMinutes,
    'cook_minutes': cookMinutes,
  };
  bool get valid =>
      title.trim().runes.isNotEmpty &&
      title.trim().runes.length <= 120 &&
      category.trim().runes.isNotEmpty &&
      category.trim().runes.length <= 60 &&
      (description?.runes.length ?? 0) <= 4000 &&
      RecipeValidation.decimal(servings, 10000, 2) &&
      [
        prepMinutes,
        cookMinutes,
      ].every((n) => n == null || (n >= 0 && n <= 10080)) &&
      ingredients.isNotEmpty &&
      ingredients.length <= 100 &&
      ingredients.every(RecipeValidation.ingredient) &&
      ingredients.map((i) => i.key).toSet().length == ingredients.length &&
      steps.isNotEmpty &&
      steps.length <= 100 &&
      steps.every(
        (s) => s.trim().runes.isNotEmpty && s.trim().runes.length <= 4000,
      );
}

abstract final class RecipeValidation {
  static double? parseDecimal(String value) =>
      double.tryParse(value.trim().replaceAll(',', '.'));
  static bool decimal(double value, double max, int precision) =>
      value.isFinite &&
      value > 0 &&
      value <= max &&
      (value * pow(10, precision) - (value * pow(10, precision)).round())
              .abs() <
          0.0000001;
  static bool ingredient(RecipeIngredient i) =>
      (i.ingredientId != null) != (i.customName != null) &&
      (i.customName == null ||
          (i.customName!.trim().runes.isNotEmpty &&
              i.customName!.trim().runes.length <= 80)) &&
      (i.quantity == null || decimal(i.quantity!, 1000000, 3)) &&
      (i.unit == null ||
          (i.unit!.trim().runes.isNotEmpty &&
              i.unit!.trim().runes.length <= 30));
}

class Recipe {
  const Recipe({
    required this.id,
    required this.authorId,
    required this.title,
    required this.category,
    required this.servings,
    required this.visibility,
    required this.version,
    required this.updatedAt,
    this.description,
    this.prepMinutes,
    this.cookMinutes,
    this.photoPath,
    this.ingredients = const [],
    this.steps = const [],
  });
  final String id, authorId, title, category;
  final String? description, photoPath;
  final double servings;
  final RecipeVisibility visibility;
  final int version;
  final DateTime updatedAt;
  final int? prepMinutes, cookMinutes;
  final List<RecipeIngredient> ingredients;
  final List<String> steps;
  int? get totalMinutes => prepMinutes == null && cookMinutes == null
      ? null
      : (prepMinutes ?? 0) + (cookMinutes ?? 0);
  factory Recipe.fromJson(Map<String, dynamic> json) {
    final items =
        (json['recipe_ingredients'] as List? ?? [])
            .cast<Map<String, dynamic>>()
            .toList()
          ..sort(
            (a, b) =>
                (a['sort_order'] as int).compareTo(b['sort_order'] as int),
          );
    final instructions =
        (json['recipe_steps'] as List? ?? [])
            .cast<Map<String, dynamic>>()
            .toList()
          ..sort(
            (a, b) =>
                (a['sort_order'] as int).compareTo(b['sort_order'] as int),
          );
    return Recipe(
      id: json['id'] as String,
      authorId: json['author_id'] as String,
      title: json['title'] as String,
      category: json['category'] as String,
      description: json['description'] as String?,
      servings: (json['servings'] as num).toDouble(),
      visibility: RecipeVisibility.values.byName(json['visibility'] as String),
      version: json['version'] as int,
      updatedAt: DateTime.parse(json['updated_at'] as String),
      prepMinutes: json['prep_minutes'] as int?,
      cookMinutes: json['cook_minutes'] as int?,
      photoPath: json['hero_image_path'] as String?,
      ingredients: List.unmodifiable(items.map(RecipeIngredient.fromJson)),
      steps: List.unmodifiable(
        instructions.map((v) => v['instruction'] as String),
      ),
    );
  }
}

class RecipeFilter {
  const RecipeFilter({this.search = '', this.category, this.visibility});
  final String search;
  final String? category;
  final RecipeVisibility? visibility;
}

class RecipeCursor {
  const RecipeCursor(this.updatedAt, this.id);
  final DateTime updatedAt;
  final String id;
}

class RecipePage {
  const RecipePage(
    this.recipes, {
    this.cursor,
    this.loadingMore = false,
    this.moreFailure,
  });
  final List<Recipe> recipes;
  final RecipeCursor? cursor;
  final bool loadingMore;
  final Object? moreFailure;
}
