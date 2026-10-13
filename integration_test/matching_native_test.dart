// Actual Android UI and isolated local backend. No repository overrides.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:image/image.dart' as img;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mixtick/app/router.dart';
import 'package:mixtick/core/config/app_config.dart';
import 'package:mixtick/features/auth/presentation/auth_controller.dart';
import 'package:mixtick/features/community/data/supabase_community_repository.dart';
import 'package:mixtick/features/cook_today/domain/matching.dart';
import 'package:mixtick/features/cook_today/presentation/cook_today_page.dart';
import 'package:mixtick/features/cook_today/presentation/matching_providers.dart';
import 'package:mixtick/features/recipes/data/supabase_recipe_repository.dart';
import 'package:mixtick/features/recipes/domain/recipe.dart';
import 'package:mixtick/features/recipes/domain/recipe_repository.dart';
import 'package:mixtick/features/recipes/presentation/recipe_detail_page.dart';
import 'package:mixtick/features/recipes/presentation/recipe_providers.dart';
import 'package:mixtick/shared/models/app_module.dart';

import 'native_test_helpers.dart';

String catalogId(int n) =>
    '10000000-0000-4000-8000-${n.toString().padLeft(12, '0')}';
Future<void> matchingTap(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      finder,
      180,
      scrollable: find.byType(Scrollable).first,
    );
  }
  await tester.ensureVisible(finder);
  await tester.pump(const Duration(milliseconds: 350));
  await tester.tap(finder);
  await tester.pump(const Duration(milliseconds: 350));
}

Future<void> nativeSelect(WidgetTester tester, String text, int id) async {
  final input = find.byKey(const ValueKey('matching-input'));
  await tester.ensureVisible(input);
  await tester.enterText(input, text);
  await tester.pump(const Duration(milliseconds: 500));
  final catalog = ProviderScope.containerOf(tester.element(input))
      .read(ingredientCatalogProvider);
  debugPrint(
    'P6_SELECT:$text catalog=${catalog.value?.length} loading=${catalog.isLoading} error=${catalog.hasError} field=${tester.widget<TextField>(input).controller!.text}',
  );
  debugPrint('P6_SCREEN:matching-debug');
  await until(
    tester,
    () => find
        .byKey(ValueKey('suggestion-${catalogId(id)}'))
        .evaluate()
        .isNotEmpty,
  );
  await matchingTap(
    tester,
    find.byKey(ValueKey('suggestion-${catalogId(id)}')),
  );
  await until(
    tester,
    () =>
        find.byKey(ValueKey('selected-${catalogId(id)}')).evaluate().isNotEmpty,
  );
}

Future<void> matchingShot(WidgetTester tester, String name) async {
  await tester.pump(const Duration(milliseconds: 800));
  await Future<void>.delayed(const Duration(milliseconds: 500));
  await tester.pump();
  debugPrint('P6_SCREEN:$name');
  await Future<void>.delayed(const Duration(seconds: 3));
  await tester.pump();
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  WidgetController.hitTestWarningShouldBeFatal = true;
  testWidgets(
    'M32 Android real: alias/chips, exact/near, photos, original detail, privacy revalidation and account isolation',
    (tester) async {
      const config = AppConfig.fromEnvironment();
      if (!config.allowLocalBackend ||
          config.supabaseUrl != 'http://10.0.2.2:54321') {
        throw StateError('Only isolated local emulator endpoint allowed');
      }
      final suffix = newRecipeRequestId().replaceAll('-', '').substring(0, 10),
          password = 'P6-native-${newRecipeRequestId()}!';
      final emails = {
        for (final letter in ['a', 'b', 'c'])
          letter: 'mixtick-p6-native-$suffix-$letter@example.test',
      };
      final creator = SupabaseClient(
        config.supabaseUrl,
        config.publishableKey,
        authOptions: const AuthClientOptions(
          authFlowType: AuthFlowType.implicit,
          autoRefreshToken: false,
        ),
      );
      late String publicId, privateId, nearId;
      final image = img.Image(width: 800, height: 600)
        ..clear(img.ColorRgb8(231, 219, 194));
      img.fillCircle(
        image,
        x: 400,
        y: 300,
        radius: 255,
        color: img.ColorRgb8(250, 249, 240),
      );
      img.fillCircle(
        image,
        x: 400,
        y: 300,
        radius: 200,
        color: img.ColorRgb8(219, 165, 55),
      );
      for (var i = 0; i < 6; i++) {
        img.fillCircle(
          image,
          x: 290 + (i % 3) * 110,
          y: 235 + (i ~/ 3) * 130,
          radius: 25,
          color: img.ColorRgb8(154, 91, 30),
        );
      }
      RecipeIngredient line(int n, {bool optional = false}) => RecipeIngredient(
        ingredientId: catalogId(n),
        name: 'Catálogo $n',
        quantity: 1,
        unit: 'ud',
        optional: optional,
      );
      for (final letter in ['a', 'b', 'c']) {
        final response = await creator.auth.signUp(
          email: emails[letter]!,
          password: password,
        );
        expect(response.session, isNotNull);
        debugPrint(
          'P6_FIXTURE:${jsonEncode({'id': response.user!.id, 'email': emails[letter]})}',
        );
        await creator.from('profiles').insert({
          'username': 'p6n_${suffix}_$letter',
          'display_name': letter == 'a'
              ? 'Cocina de prueba'
              : 'Prueba Android ${letter.toUpperCase()}',
        });
        final recipes = SupabaseRecipeRepository(creator);
        if (letter == 'a') {
          final items = [
            line(4),
            line(3),
            line(6),
            line(8),
            line(2, optional: true),
          ];
          publicId = await recipes.save(
            RecipeDraft(
              title: 'Tortilla de patatas',
              category: 'Principal',
              servings: 2,
              prepMinutes: 10,
              cookMinutes: 20,
              ingredients: items,
              steps: ['Batir y mezclar.', 'Cuajar la tortilla.'],
            ),
            requestId: newRecipeRequestId(),
          );
          var recipe = (await recipes.read(publicId))!;
          final path = await recipes.uploadPhoto(
            recipe,
            img.encodePng(image),
            PhotoCancellation(),
          );
          await recipes.setPhoto(recipe, path);
          recipe = (await recipes.read(publicId))!;
          await recipes.setVisibility(recipe, RecipeVisibility.public);
          privateId = await recipes.save(
            RecipeDraft(
              title: 'Privada de A: no mostrar a B',
              category: 'Privada',
              servings: 1,
              ingredients: items,
              steps: ['Instrucción privada'],
            ),
            requestId: newRecipeRequestId(),
          );
        }
        if (letter == 'b') {
          await SupabaseCommunityRepository(creator).save(publicId, true);
        }
        if (letter == 'c') {
          nearId = await recipes.save(
            RecipeDraft(
              title: 'Tortilla con queso',
              category: 'Principal',
              servings: 2,
              prepMinutes: 5,
              cookMinutes: 20,
              ingredients: [line(4), line(3), line(6), line(8), line(33)],
              steps: ['Agregar queso.'],
            ),
            requestId: newRecipeRequestId(),
          );
          await recipes.setVisibility(
            (await recipes.read(nearId))!,
            RecipeVisibility.public,
          );
        }
      }
      final container = await mountNative(tester, config);
      await matchingTap(tester, find.text('Iniciar sesión').first);
      await submitNative(tester, emails['b']!, password);
      await until(
        tester,
        () => find.byType(NavigationDestination).evaluate().length == 4,
      );
      await matchingTap(
        tester,
        find.byKey(const ValueKey(AppModule.cookToday)),
      );
      for (final item in [
        ('Huevos', 4),
        ('Patatas', 3),
        ('AOVE', 6),
        ('Sal', 8),
      ]) {
        await nativeSelect(tester, item.$1, item.$2);
      }
      expect(find.byType(InputChip), findsNWidgets(4));
      await nativeSelect(tester, 'huevo', 4);
      expect(find.byType(InputChip), findsNWidgets(4));
      // Dismiss keyboard and settle actual data/photograph before screenshots.
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump(const Duration(milliseconds: 600));
      final q = MatchingQuery([
        for (final id in [4, 3, 6, 8])
          SelectedIngredient(id: catalogId(id), name: 'Catálogo $id'),
      ], MatchingMode.exact);
      await until(
        tester,
        () =>
            container.read(matchingPagesProvider(q)).value?.matches.length == 1,
      );
      expect(
        container
            .read(matchingPagesProvider(q))
            .value!
            .matches
            .single
            .recipe
            .id,
        publicId,
      );
      expect(find.text('Privada de A: no mostrar a B'), findsNothing);
      tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position
          .jumpTo(0);
      await tester.pump();
      await matchingShot(tester, 'matching-selection');
      await tester.scrollUntilVisible(
        find.byKey(ValueKey('match-open-$publicId')),
        140,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.byKey(ValueKey('match-open-$publicId')));
      await tester.pump();
      await until(
        tester,
        () => find
            .byWidgetPredicate((w) => w is Image && w.height == 180)
            .evaluate()
            .isNotEmpty,
      );
      await matchingShot(tester, 'matching-light');
      await until(
        tester,
        () =>
            Theme.of(tester.element(find.byType(MatchingCard).first))
                .brightness ==
            Brightness.dark,
      );
      await matchingShot(tester, 'matching-dark');
      await until(
        tester,
        () =>
            Theme.of(tester.element(find.byType(MatchingCard).first))
                .brightness ==
            Brightness.light,
      );
      await matchingTap(tester, find.byKey(const ValueKey('matching-near')));
      final nearQuery = MatchingQuery(q.selected, MatchingMode.near);
      await until(
        tester,
        () =>
            container
                .read(matchingPagesProvider(nearQuery))
                .value
                ?.matches
                .length ==
            2,
      );
      expect(
        container
            .read(matchingPagesProvider(nearQuery))
            .value!
            .matches
            .last
            .recipe
            .id,
        nearId,
      );
      await matchingTap(tester, find.byKey(ValueKey('match-open-$publicId')));
      await until(
        tester,
        () => find.text('Cuajar la tortilla.').evaluate().isNotEmpty,
      );
      expect(
        tester.widget<RecipeDetailPage>(find.byType(RecipeDetailPage)).id,
        publicId,
      );
      expect(find.byKey(const ValueKey('edit-recipe')), findsNothing);
      await creator.auth.signInWithPassword(
        email: emails['a']!,
        password: password,
      );
      final recipes = SupabaseRecipeRepository(creator);
      await recipes.setVisibility(
        (await recipes.read(publicId))!,
        RecipeVisibility.private,
      );
      await matchingTap(tester, find.byTooltip('Recargar receta'));
      await until(
        tester,
        () => find
            .text('Esta receta no está disponible para tu cuenta.')
            .evaluate()
            .isNotEmpty,
      );
      expect(find.text('Cuajar la tortilla.'), findsNothing);
      await matchingTap(tester, find.byType(BackButton));
      await until(
        tester,
        () =>
            container
                .read(matchingPagesProvider(nearQuery))
                .value
                ?.matches
                .length ==
            1,
      );
      expect(
        container
            .read(matchingPagesProvider(nearQuery))
            .value!
            .matches
            .single
            .recipe
            .id,
        nearId,
      );
      await container
          .read(authControllerProvider.notifier)
          .execute((auth) => auth.signOut());
      await until(
        tester,
        () => find.text('Tu cocina, en un solo lugar').evaluate().isNotEmpty,
      );
      await matchingTap(tester, find.text('Iniciar sesión').first);
      await submitNative(tester, emails['a']!, password);
      await until(
        tester,
        () => find.byType(NavigationDestination).evaluate().length == 4,
      );
      container.read(routerProvider).go('/cook-today');
      await tester.pump();
      await until(
        tester,
        () =>
            find.byKey(const ValueKey('matching-input')).evaluate().isNotEmpty,
      );
      expect(find.byType(InputChip), findsNothing);
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('matching-input')))
            .controller!
            .text,
        isEmpty,
      );
      for (final item in [
        ('huevo', 4),
        ('patata', 3),
        ('AOVE', 6),
        ('sal', 8),
      ]) {
        await nativeSelect(tester, item.$1, item.$2);
      }
      await until(
        tester,
        () =>
            container.read(matchingPagesProvider(q)).value?.matches.length == 2,
      );
      expect(
        container
            .read(matchingPagesProvider(q))
            .value!
            .matches
            .any((r) => r.recipe.id == privateId),
        true,
      );
      await container
          .read(authControllerProvider.notifier)
          .execute((auth) => auth.signOut());
      await until(
        tester,
        () => find.text('Tu cocina, en un solo lugar').evaluate().isNotEmpty,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
      await creator.dispose();
    },
  );
}
