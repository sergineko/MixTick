// Widget/provider doubles prove UI and state only. RLS is tested separately.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mixtick/app/app.dart';
import 'package:mixtick/app/router.dart';
import 'package:mixtick/features/auth/domain/auth_session.dart';
import 'package:mixtick/features/auth/presentation/auth_providers.dart';
import 'package:mixtick/features/cook_today/domain/matching.dart';
import 'package:mixtick/features/cook_today/presentation/cook_today_page.dart';
import 'package:mixtick/features/cook_today/presentation/matching_providers.dart';
import 'package:mixtick/features/profile/domain/user_profile.dart';
import 'package:mixtick/features/recipes/domain/recipe.dart';
import 'package:mixtick/features/recipes/presentation/recipe_detail_page.dart';
import 'package:mixtick/features/recipes/presentation/recipe_providers.dart';
import 'package:mixtick/shared/models/app_module.dart';

import '../support/fake_recipe_repository.dart';

RecipeMatch matchFixture({
  String id = '20000000-0000-4000-8000-000000000001',
  int missing = 0,
}) => RecipeMatch(
  recipe: testRecipe(id: id),
  author: const PublicProfile(username: 'test_a', displayName: 'Prueba A'),
  required: 1 + missing,
  matched: 1,
  missing: missing,
  optionalMatched: 0,
  cursor: MatchingCursor(missing: missing, rank: 0, minutes: 10, id: id),
  missingIngredients: [
    if (missing > 0)
      const MissingIngredient(
        lineId: 'test-line',
        ordinal: 1,
        ingredient: RecipeIngredient(
          customName: 'Miso',
          name: 'Miso',
          quantity: 0.125,
          unit: 'kg',
        ),
      ),
  ],
);

class FakeMatching implements MatchingRepository {
  final queries = <MatchingQuery>[], cancellations = <MatchingCancellation>[];
  List<RecipeMatch> rows = [matchFixture()];
  MatchingFailure? failure;
  Completer<MatchingPage>? pending;
  bool paginated = false;
  @override
  Future<MatchingPage> search(
    MatchingQuery query, {
    MatchingCursor? cursor,
    MatchingCancellation? cancellation,
  }) async {
    queries.add(query);
    if (cancellation != null) cancellations.add(cancellation);
    if (pending != null) return pending!.future;
    if (failure != null) throw failure!;
    return MatchingPage(
      rows,
      cursor: paginated && cursor == null ? rows.last.cursor : null,
    );
  }
}

class DelayedIngredientRepository extends FakeRecipeRepository {
  final gate = Completer<void>();
  @override
  Future<CatalogIngredient?> resolveIngredient(String name) async {
    await gate.future;
    return super.resolveIngredient(name);
  }
}

Future<ProviderContainer> mountMatching(
  WidgetTester tester,
  FakeMatching repo, {
  Stream<AuthSession?>? sessions,
  FakeRecipeRepository? recipeOverride,
}) async {
  final recipes = recipeOverride ?? FakeRecipeRepository();
  recipes.recipes.addEntries(
    repo.rows.map((m) => MapEntry(m.recipe.id, m.recipe)),
  );
  final container = ProviderContainer(
    overrides: [
      initialLocationProvider.overrideWithValue('/cook-today'),
      authSessionProvider.overrideWith(
        (ref) => sessions ?? Stream.value(const AuthSession(userId: 'test-a')),
      ),
      matchingRepositoryProvider.overrideWithValue(repo),
      recipeRepositoryProvider.overrideWithValue(recipes),
    ],
  );
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    container.dispose();
  });
  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const MixTickApp()),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  return container;
}

Future<void> tapMatch(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      finder,
      180,
      scrollable: find.byType(Scrollable).first,
    );
  }
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> selectName(WidgetTester tester, String name) async {
  final field = find.byKey(const ValueKey('matching-input'));
  await tester.ensureVisible(field);
  await tester.enterText(field, name);
  await tester.pump();
  await tapMatch(tester, find.byKey(const ValueKey('matching-add')));
}

void main() {
  WidgetController.hitTestWarningShouldBeFatal = true;
  testWidgets(
    'M26 pending ingredient resolution preserves newer typed text and keyboard focus (mock)',
    (tester) async {
      final recipeRepo = DelayedIngredientRepository();
      await mountMatching(tester, FakeMatching(), recipeOverride: recipeRepo);
      final input = find.byKey(const ValueKey('matching-input'));
      await tester.enterText(input, 'Huevos');
      await tester.pump();
      await tester.ensureVisible(find.byKey(const ValueKey('matching-add')));
      await tester.tap(find.byKey(const ValueKey('matching-add')));
      await tester.pump();
      expect(tester.widget<TextField>(input).enabled, true);
      await tester.enterText(input, 'Tomates');
      await tester.pump();
      recipeRepo.gate.complete();
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(input).controller!.text, 'Tomates');
      expect(tester.widget<TextField>(input).focusNode!.hasFocus, true);
      expect(find.byKey(ValueKey('selected-${egg.id}')), findsOneWidget);
    },
  );
  test('M03 M33 selection has bounded names and canonical set identity', () {
    final query = MatchingQuery([
      SelectedIngredient(id: egg.id, name: 'Huevo'),
    ], MatchingMode.exact);
    expect(query.valid, true);
    expect(
      MatchingQuery([
        SelectedIngredient(id: egg.id, name: 'Huevo'),
        SelectedIngredient(id: egg.id, name: 'Huevos'),
      ], MatchingMode.exact).valid,
      false,
    );
    expect(
      MatchingQuery(
        List.generate(51, (i) => SelectedIngredient(name: 'Nombre $i')),
        MatchingMode.exact,
      ).valid,
      false,
    );
    expect(SelectedIngredient(name: 'x' * 81).valid, false);
    expect(const SelectedIngredient(name: '\t ').valid, false);
  });
  test(
    'M16 free names match only exact normalized key, no semantic substitutions',
    () {
      expect(
        const SelectedIngredient(name: ' MÍSO  blanco ').key,
        'free:miso blanco',
      );
      expect(
        const SelectedIngredient(name: 'Miso').key,
        isNot(const SelectedIngredient(name: 'Miso blanco').key),
      );
      expect(const SelectedIngredient(name: 'aceite').id, isNull);
    },
  );
  test('M25 M26 query is immutable and order independent', () {
    final selected = [
      SelectedIngredient(id: egg.id, name: 'Huevo'),
      SelectedIngredient(id: tomato.id, name: 'Tomate'),
    ];
    final one = MatchingQuery(selected, MatchingMode.exact),
        two = MatchingQuery(selected.reversed, MatchingMode.exact);
    expect(one, two);
    expect(one.hashCode, two.hashCode);
    selected.clear();
    expect(one.selected.length, 2);
    expect(one, isNot(MatchingQuery(one.selected, MatchingMode.near)));
  });
  test('M18 transfer preserves recipe quantity and original line without home quantities', () {
    final transfer = matchFixture(missing: 1).transfer;
    expect(transfer.lines.single.ingredient.quantity, 0.125);
    expect(transfer.lines.single.ingredient.unit, 'kg');
    expect(transfer.lines.single.ordinal, 1);
    expect(transfer.recipeVersion, 1);
    expect(() => transfer.lines.clear(), throwsUnsupportedError);
  });
  testWidgets('M17 empty selection causes no recipe search (mock)', (
    tester,
  ) async {
    final repo = FakeMatching();
    await mountMatching(tester, repo);
    await tester.pumpAndSettle();
    expect(repo.queries, isEmpty);
    expect(find.byType(NavigationDestination), findsNWidgets(4));
    await tapMatch(
      tester,
      find.text('Añade los ingredientes que tienes ahora para buscar recetas.'),
    );
  });
  testWidgets(
    'M01 M02 M03 select alias, canonical chip, no duplicates, selector remains open (mock)',
    (tester) async {
      final repo = FakeMatching();
      await mountMatching(tester, repo);
      await selectName(tester, 'HUEVOS');
      expect(find.byKey(ValueKey('selected-${egg.id}')), findsOneWidget);
      await selectName(tester, 'huevo');
      expect(find.byType(InputChip), findsOneWidget);
      expect(
        find.text('Este ingrediente ya está seleccionado.'),
        findsOneWidget,
      );
      await selectName(tester, 'Tomates');
      expect(find.byType(InputChip), findsNWidgets(2));
      expect(repo.queries.last.ids.toSet(), {egg.id, tomato.id});
    },
  );
  testWidgets(
    'M04 M05 remove one ingredient then clear, no empty search (mock)',
    (tester) async {
      final repo = FakeMatching();
      await mountMatching(tester, repo);
      await selectName(tester, 'Huevos');
      await selectName(tester, 'Tomate');
      await tapMatch(tester, find.byTooltip('Quitar Huevo'));
      expect(repo.queries.last.ids, [tomato.id]);
      final calls = repo.queries.length;
      await tapMatch(tester, find.byKey(const ValueKey('matching-clear')));
      expect(find.byType(InputChip), findsNothing);
      expect(repo.queries.length, calls);
    },
  );
  testWidgets(
    'M06 unknown and ambiguous names remain literal instead of invented canonical IDs (mock)',
    (tester) async {
      final repo = FakeMatching();
      await mountMatching(tester, repo);
      await selectName(tester, 'aceite');
      expect(repo.queries.last.ids, isEmpty);
      expect(repo.queries.last.names, ['aceite']);
      await selectName(tester, 'Miso blanco');
      expect(repo.queries.last.names, ['aceite', 'miso blanco']);
    },
  );
  testWidgets('M10 M28 full/near modes and original detail navigation (mock)', (
    tester,
  ) async {
    final repo = FakeMatching();
    await mountMatching(tester, repo);
    await selectName(tester, 'Huevos');
    await tapMatch(tester, find.byKey(const ValueKey('matching-near')));
    expect(repo.queries.last.mode, MatchingMode.near);
    await tapMatch(
      tester,
      find.byKey(ValueKey('match-open-${repo.rows.first.recipe.id}')),
    );
    expect(find.byType(RecipeDetailPage), findsOneWidget);
    expect(find.text('Batir los huevos.'), findsOneWidget);
  });
  testWidgets(
    'M27 error hides rows and manual retry restores server data (mock)',
    (tester) async {
      final repo = FakeMatching()
        ..failure = const MatchingFailure(MatchingFailureCode.network);
      await mountMatching(tester, repo);
      await selectName(tester, 'Huevos');
      expect(find.byType(MatchingCard), findsNothing);
      repo.failure = null;
      await tapMatch(tester, find.text('Reintentar').last);
      await tester.scrollUntilVisible(
        find.byType(MatchingCard),
        180,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.byType(MatchingCard), findsOneWidget);
    },
  );
  testWidgets('M25 pagination deduplicates overlapping server IDs (mock)', (
    tester,
  ) async {
    final repo = FakeMatching()..paginated = true;
    final container = await mountMatching(tester, repo);
    await selectName(tester, 'Huevos');
    final query = repo.queries.last;
    await container.read(matchingPagesProvider(query).notifier).loadMore();
    await tester.pumpAndSettle();
    expect(
      container.read(matchingPagesProvider(query)).value!.matches.length,
      1,
    );
  });
  testWidgets(
    'M24 M26 late response and selection discarded on account change (mock)',
    (tester) async {
      final stream = StreamController<AuthSession?>();
      addTearDown(stream.close);
      final repo = FakeMatching()..pending = Completer<MatchingPage>();
      await mountMatching(tester, repo, sessions: stream.stream);
      stream.add(const AuthSession(userId: 'test-a'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('matching-input')),
        'Huevos',
      );
      await tester.pump();
      await tester.ensureVisible(find.byKey(const ValueKey('matching-add')));
      await tester.tap(find.byKey(const ValueKey('matching-add')));
      await tester.pump(const Duration(milliseconds: 350));
      final cancelled = Completer<void>();
      repo.cancellations.last.signal.then((_) => cancelled.complete());
      stream.add(const AuthSession(userId: 'test-b'));
      await tester.pumpAndSettle();
      await cancelled.future;
      repo.pending!.complete(MatchingPage(repo.rows));
      await tester.pumpAndSettle();
      expect(find.byType(InputChip), findsNothing);
      expect(find.byType(MatchingCard), findsNothing);
    },
  );
  testWidgets(
    'M29 selection shared only within cook screen, other four routes retained (mock)',
    (tester) async {
      final repo = FakeMatching();
      final container = await mountMatching(tester, repo);
      await selectName(tester, 'Huevos');
      for (final module in [
        AppModule.community,
        AppModule.recipes,
        AppModule.shopping,
        AppModule.cookToday,
      ]) {
        container.read(routerProvider).go(module.path);
        await tester.pumpAndSettle();
        expect(find.byType(NavigationDestination), findsNWidgets(4));
      }
    },
  );
  for (final brightness in Brightness.values) {
    testWidgets(
      'M34 small 320x640 and 200% selection/results/keyboard $brightness (mock)',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.platformBrightnessTestValue = brightness;
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final repo = FakeMatching()..rows = [matchFixture(missing: 2)];
        await mountMatching(tester, repo);
        await selectName(tester, 'Huevos');
        await tapMatch(tester, find.byKey(const ValueKey('matching-near')));
        await tester.scrollUntilVisible(
          find.byType(MatchingCard),
          140,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(
          Theme.of(tester.element(find.byType(MatchingCard))).brightness,
          brightness,
        );
      },
    );
  }
}
