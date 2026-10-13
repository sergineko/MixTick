import 'dart:async';

import '../../profile/domain/user_profile.dart';
import '../../recipes/domain/recipe.dart';

enum MatchingMode { exact, near }

enum MatchingFailureCode { network, forbidden, invalid, unexpected }

class MatchingFailure implements Exception {
  const MatchingFailure(this.code);
  final MatchingFailureCode code;
}

class MatchingCancellation {
  final _completion = Completer<void>();
  Future<void> get signal => _completion.future;
  void cancel() {
    if (!_completion.isCompleted) _completion.complete();
  }
}

/// Presence only. No available quantity, persistence or inferred substitutes.
class SelectedIngredient {
  const SelectedIngredient({required this.name, this.id});
  final String name;
  final String? id;
  String get key => id ?? 'free:${normalizeIngredientText(name)}';
  bool get valid => name.trim().runes.isNotEmpty && name.runes.length <= 80;
}

class MatchingQuery {
  MatchingQuery(Iterable<SelectedIngredient> selected, this.mode)
    : selected = List.unmodifiable(selected);
  final List<SelectedIngredient> selected;
  final MatchingMode mode;
  List<String> get ids =>
      selected.where((i) => i.id != null).map((i) => i.id!).toList()..sort();
  List<String> get names =>
      selected
          .where((i) => i.id == null)
          .map((i) => normalizeIngredientText(i.name))
          .toList()
        ..sort();
  bool get valid =>
      selected.length <= 50 &&
      selected.every((i) => i.valid) &&
      selected.map((i) => i.key).toSet().length == selected.length;
  @override
  bool operator ==(Object other) =>
      other is MatchingQuery &&
      mode == other.mode &&
      _signature == other._signature;
  String get _signature =>
      (selected.map((i) => i.key).toList()..sort()).join('\u0000');
  @override
  int get hashCode => Object.hash(mode, _signature);
}

class MatchingCursor {
  const MatchingCursor({
    required this.missing,
    required this.rank,
    required this.minutes,
    required this.id,
  });
  final int missing, rank, minutes;
  final String id;
  Map<String, dynamic> toJson() => {
    'missing': missing,
    'rank': rank,
    'minutes': minutes,
    'id': id,
  };
  factory MatchingCursor.fromJson(Map<String, dynamic> row) => MatchingCursor(
    missing: row['missing'] as int,
    rank: row['rank'] as int,
    minutes: row['minutes'] as int,
    id: row['id'] as String,
  );
}

/// Original line identity/ordinal and required quantity are preserved for phase 07.
/// Any import must first revalidate recipe access/version; this is not a write.
class MissingIngredient {
  const MissingIngredient({
    required this.lineId,
    required this.ordinal,
    required this.ingredient,
    this.effectiveId,
  });
  final String lineId;
  final int ordinal;
  final String? effectiveId;
  final RecipeIngredient ingredient;
  factory MissingIngredient.fromJson(Map<String, dynamic> row) =>
      MissingIngredient(
        lineId: row['line_id'] as String,
        ordinal: row['sort_order'] as int,
        effectiveId: row['effective_id'] as String?,
        ingredient: RecipeIngredient.fromJson(row),
      );
}

class MissingIngredientsTransfer {
  const MissingIngredientsTransfer({
    required this.recipeId,
    required this.recipeVersion,
    required this.lines,
  });
  final String recipeId;
  final int recipeVersion;
  final List<MissingIngredient> lines;
}

class RecipeMatch {
  const RecipeMatch({
    required this.recipe,
    required this.author,
    required this.required,
    required this.matched,
    required this.missing,
    required this.optionalMatched,
    required this.cursor,
    this.missingIngredients = const [],
  });
  final Recipe recipe;
  final PublicProfile author;
  final int required, matched, missing, optionalMatched;
  final MatchingCursor cursor;
  final List<MissingIngredient> missingIngredients;
  MissingIngredientsTransfer get transfer => MissingIngredientsTransfer(
    recipeId: recipe.id,
    recipeVersion: recipe.version,
    lines: List.unmodifiable(missingIngredients),
  );
  factory RecipeMatch.fromJson(Map<String, dynamic> row) => RecipeMatch(
    recipe: Recipe.fromJson(row['recipe'] as Map<String, dynamic>),
    author: PublicProfile.fromJson(row['author'] as Map<String, dynamic>),
    required: row['required'] as int,
    matched: row['matched'] as int,
    missing: row['missing'] as int,
    optionalMatched: row['optional_matched'] as int,
    cursor: MatchingCursor.fromJson(row['cursor'] as Map<String, dynamic>),
    missingIngredients: List.unmodifiable(
      (row['missing_ingredients'] as List).map(
        (i) => MissingIngredient.fromJson(i as Map<String, dynamic>),
      ),
    ),
  );
}

class MatchingPage {
  const MatchingPage(
    this.matches, {
    this.cursor,
    this.loadingMore = false,
    this.moreFailure,
  });
  final List<RecipeMatch> matches;
  final MatchingCursor? cursor;
  final bool loadingMore;
  final Object? moreFailure;
}

abstract interface class MatchingRepository {
  Future<MatchingPage> search(
    MatchingQuery query, {
    MatchingCursor? cursor,
    MatchingCancellation? cancellation,
  });
}
