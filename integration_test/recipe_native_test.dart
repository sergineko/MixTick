// Actual Flutter UI + native image_picker + local Auth/PostgREST/Storage.
// Fixture setup uses real Auth; no application repositories are overridden.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mixtick/app/router.dart';
import 'package:mixtick/core/config/app_config.dart';
import 'package:mixtick/features/auth/presentation/auth_controller.dart';
import 'package:mixtick/features/profile/data/supabase_profile_repository.dart';
import 'package:mixtick/features/recipes/domain/recipe.dart';
import 'package:mixtick/features/recipes/presentation/recipe_detail_page.dart';
import 'package:mixtick/features/recipes/presentation/recipe_providers.dart';
import 'package:mixtick/shared/models/app_module.dart';

import 'native_test_helpers.dart';

Future<void> shot(WidgetTester tester, String name) async {
  // Capture after image decoding and Material theme/button transitions settle.
  await tester.pump(const Duration(milliseconds: 800));
  await Future<void>.delayed(const Duration(milliseconds: 400));
  await tester.pump();
  debugPrint('P4_SCREEN:$name');
  await Future<void>.delayed(const Duration(seconds: 3));
  await tester.pump();
}

Future<void> nativeLogin(
  WidgetTester tester,
  String email,
  String password,
) async {
  await nativeTap(tester, find.text('Iniciar sesión').first);
  await submitNative(tester, email, password);
  await until(
    tester,
    () => find.byType(NavigationDestination).evaluate().length == 4,
  );
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  WidgetController.hitTestWarningShouldBeFatal = true;
  testWidgets(
    'Android real: recipe CRUD, native gallery cancel/select, privacy, dark/light and account isolation',
    (tester) async {
      const config = AppConfig.fromEnvironment();
      if (!config.allowLocalBackend ||
          config.supabaseUrl != 'http://10.0.2.2:54321') {
        throw StateError('Only isolated local emulator backend is permitted');
      }
      final suffix = newRecipeRequestId().replaceAll('-', '').substring(0, 10);
      final password = 'P4-native-${newRecipeRequestId()}!';
      final emailA = 'mixtick-p4-native-$suffix-a@example.test',
          emailB = 'mixtick-p4-native-$suffix-b@example.test';
      final creator = SupabaseClient(
        config.supabaseUrl,
        config.publishableKey,
        authOptions: const AuthClientOptions(
          authFlowType: AuthFlowType.implicit,
          autoRefreshToken: false,
        ),
      );
      for (final letter in ['a', 'b']) {
        final email = letter == 'a' ? emailA : emailB;
        final response = await creator.auth.signUp(
          email: email,
          password: password,
        );
        expect(response.session, isNotNull);
        debugPrint(
          'P4_FIXTURE:${jsonEncode({'id': response.user!.id, 'email': email})}',
        );
        await SupabaseProfileRepository(creator).save(
          username: 'p4n_${suffix}_$letter',
          displayName: 'Prueba Android ${letter.toUpperCase()}',
        );
      }
      await creator.dispose();
      final container = await mountNative(tester, config);
      expect(
        find.text('Tu cocina, en un solo lugar'),
        findsOneWidget,
        reason: 'Emulator must not contain an unrelated active account',
      );
      await nativeLogin(tester, emailA, password);
      await nativeTap(tester, find.byKey(const ValueKey(AppModule.recipes)));
      await nativeTap(tester, find.byKey(const ValueKey('create-recipe')));
      await until(
        tester,
        () => find.byKey(const ValueKey('recipe-title')).evaluate().isNotEmpty,
      );
      await tester.enterText(
        find.byKey(const ValueKey('recipe-title')),
        'Sopa de tomates · Android',
      );
      await tester.enterText(
        find.byKey(const ValueKey('recipe-category')),
        'Entrante',
      );
      await tester.enterText(
        find.byKey(const ValueKey('recipe-servings')),
        '2,5',
      );
      await tester.enterText(find.byKey(const ValueKey('recipe-prep')), '10');
      await tester.enterText(find.byKey(const ValueKey('recipe-cook')), '20');
      await nativeTap(
        tester,
        find.byKey(const ValueKey('add-recipe-ingredient')),
      );
      await until(
        tester,
        () =>
            find.byKey(const ValueKey('ingredient-name')).evaluate().isNotEmpty,
      );
      await tester.enterText(
        find.byKey(const ValueKey('ingredient-name')),
        'Tomates',
      );
      await tester.enterText(
        find.byKey(const ValueKey('ingredient-quantity')),
        '1,250',
      );
      await tester.enterText(
        find.byKey(const ValueKey('ingredient-unit')),
        'kg',
      );
      await nativeTap(tester, find.byType(Switch));
      await nativeTap(tester, find.byKey(const ValueKey('confirm-ingredient')));
      await tester.enterText(
        find.byKey(const ValueKey('recipe-step-0')),
        'Cocer los tomates.',
      );
      debugPrint('P4_GALLERY:cancel');
      await nativeTap(
        tester,
        find.byKey(const ValueKey('choose-recipe-photo')),
      );
      await until(
        tester,
        () =>
            tester
                .widget<OutlinedButton>(
                  find.byKey(const ValueKey('choose-recipe-photo')),
                )
                .onPressed !=
            null,
        seconds: 90,
      );
      expect(find.byType(Image), findsNothing);
      debugPrint('P4_GALLERY:pick');
      await nativeTap(
        tester,
        find.byKey(const ValueKey('choose-recipe-photo')),
      );
      await until(
        tester,
        () => find.byType(Image).evaluate().isNotEmpty,
        seconds: 90,
      );
      await shot(tester, 'editor-gallery');
      await nativeTap(tester, find.byKey(const ValueKey('save-recipe')));
      await until(
        tester,
        () => find.byKey(const ValueKey('edit-recipe')).evaluate().isNotEmpty,
        seconds: 60,
      );
      final id = tester
          .widget<RecipeDetailPage>(find.byType(RecipeDetailPage))
          .id;
      final repo = container.read(recipeRepositoryProvider)!;
      var recipe = (await repo.read(id))!;
      expect(recipe.visibility, RecipeVisibility.private);
      expect(
        recipe.ingredients.single.ingredientId,
        '10000000-0000-4000-8000-000000000001',
      );
      expect(recipe.ingredients.single.quantity, 1.25);
      expect(recipe.ingredients.single.optional, true);
      expect(recipe.servings, 2.5);
      expect(recipe.photoPath, isNotNull);
      await until(
        tester,
        () => find
            .descendant(
              of: find.byType(RecipeContent),
              matching: find.byType(Image),
            )
            .evaluate()
            .isNotEmpty,
      );
      await shot(tester, 'detail-light');
      await until(
        tester,
        () =>
            Theme.of(tester.element(find.byType(RecipeDetailPage)))
                .brightness ==
            Brightness.dark,
      );
      await shot(tester, 'detail-dark');
      await nativeTap(tester, find.byKey(const ValueKey('edit-recipe')));
      await until(
        tester,
        () => find.byKey(const ValueKey('recipe-title')).evaluate().isNotEmpty,
      );
      await tester.enterText(
        find.byKey(const ValueKey('recipe-title')),
        'Sopa editada · Android',
      );
      await nativeTap(tester, find.byKey(const ValueKey('add-recipe-step')));
      await tester.enterText(
        find.byKey(const ValueKey('recipe-step-1')),
        'Servir con cuidado.',
      );
      await nativeTap(tester, find.byTooltip('Subir paso').last);
      await nativeTap(tester, find.byKey(const ValueKey('save-recipe')));
      await until(
        tester,
        () => find
            .byKey(const ValueKey('toggle-recipe-visibility'))
            .evaluate()
            .isNotEmpty,
      );
      recipe = (await repo.read(id))!;
      expect(recipe.title, 'Sopa editada · Android');
      expect(recipe.steps, ['Servir con cuidado.', 'Cocer los tomates.']);
      await nativeTap(
        tester,
        find.byKey(const ValueKey('toggle-recipe-visibility')),
      );
      await nativeTap(
        tester,
        find.widgetWithText(FilledButton, 'Publicar receta'),
      );
      await until(
        tester,
        () => find.text('Hacer privada').evaluate().isNotEmpty,
      );
      expect((await repo.read(id))!.visibility, RecipeVisibility.public);
      await nativeTap(
        tester,
        find.byKey(const ValueKey('toggle-recipe-visibility')),
      );
      await nativeTap(
        tester,
        find.widgetWithText(FilledButton, 'Hacer privada'),
      );
      await until(
        tester,
        () => find.text('Publicar receta').evaluate().isNotEmpty,
      );
      expect((await repo.read(id))!.visibility, RecipeVisibility.private);
      // A real Auth logout while editing forces the guard and SessionScope to
      // discard a private draft, then the next real account starts clean.
      await nativeTap(tester, find.byKey(const ValueKey('edit-recipe')));
      await until(
        tester,
        () => find.byKey(const ValueKey('recipe-title')).evaluate().isNotEmpty,
      );
      await tester.enterText(
        find.byKey(const ValueKey('recipe-title')),
        'Borrador secreto A',
      );
      await container
          .read(authControllerProvider.notifier)
          .execute((auth) => auth.signOut());
      await until(
        tester,
        () => find.text('Tu cocina, en un solo lugar').evaluate().isNotEmpty,
      );
      await nativeLogin(tester, emailB, password);
      await nativeTap(tester, find.byKey(const ValueKey(AppModule.recipes)));
      await until(
        tester,
        () => find.text('Un recetario por descubrir').evaluate().isNotEmpty,
      );
      expect(find.text('Sopa editada · Android'), findsNothing);
      expect(await repo.read(id), isNull);
      await nativeTap(tester, find.byKey(const ValueKey('create-recipe')));
      await until(
        tester,
        () => find.byKey(const ValueKey('recipe-title')).evaluate().isNotEmpty,
      );
      expect(
        tester
            .widget<TextFormField>(find.byKey(const ValueKey('recipe-title')))
            .controller!
            .text,
        isEmpty,
      );
      await container
          .read(authControllerProvider.notifier)
          .execute((auth) => auth.signOut());
      await until(
        tester,
        () => find.text('Tu cocina, en un solo lugar').evaluate().isNotEmpty,
      );
      await nativeLogin(tester, emailA, password);
      container.read(routerProvider).go('/recipes/$id');
      await until(
        tester,
        () => find.byKey(const ValueKey('delete-recipe')).evaluate().isNotEmpty,
      );
      await nativeTap(tester, find.byKey(const ValueKey('delete-recipe')));
      await nativeTap(
        tester,
        find.widgetWithText(FilledButton, 'Eliminar receta'),
      );
      await until(
        tester,
        () => find.byType(NavigationDestination).evaluate().length == 4,
      );
      expect(await repo.read(id), isNull);
      await container
          .read(authControllerProvider.notifier)
          .execute((auth) => auth.signOut());
      await until(
        tester,
        () => find.text('Tu cocina, en un solo lugar').evaluate().isNotEmpty,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
    },
  );
}
