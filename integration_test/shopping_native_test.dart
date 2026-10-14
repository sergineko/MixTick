// Actual Android UI with local Auth/PostgREST and an independent owner socket.
// No repository or permission overrides.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mixtick/app/router.dart';
import 'package:mixtick/core/config/app_config.dart';
import 'package:mixtick/features/auth/presentation/auth_controller.dart';
import 'package:mixtick/features/recipes/data/supabase_recipe_repository.dart';
import 'package:mixtick/features/recipes/domain/recipe.dart';
import 'package:mixtick/features/shopping/data/supabase_shopping_repository.dart';
import 'package:mixtick/features/shopping/domain/shopping.dart';
import 'package:mixtick/features/shopping/presentation/shopping_detail_page.dart';
import 'package:mixtick/features/shopping/presentation/shopping_import_page.dart';
import 'package:mixtick/features/shopping/presentation/shopping_providers.dart';
import 'package:mixtick/features/cook_today/presentation/cook_today_page.dart';
import 'package:mixtick/features/cook_today/presentation/matching_providers.dart';
import 'package:mixtick/features/cook_today/domain/matching.dart';
import 'package:mixtick/shared/models/app_module.dart';

import 'native_test_helpers.dart';

Future<void> shopTap(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      finder,
      180,
      scrollable: find.byType(Scrollable).first,
    );
  }
  // Recipe/social content and the native keyboard can change geometry after
  // navigation. Recheck the actual hit target instead of tapping an old offset.
  for (var retry = 0; retry < 30; retry++) {
    await tester.ensureVisible(finder);
    await tester.pump(const Duration(milliseconds: 100));
    if (finder.hitTestable().evaluate().isNotEmpty) {
      await tester.tap(finder);
      await tester.pump(const Duration(milliseconds: 400));
      return;
    }
  }
  throw TestFailure('Native shopping target did not become interactive');
}

Future<void> shoppingShot(WidgetTester tester, String name) async {
  await tester.pump(const Duration(milliseconds: 800));
  await Future<void>.delayed(const Duration(milliseconds: 500));
  await tester.pump();
  debugPrint('P7_SCREEN:$name');
  await Future<void>.delayed(const Duration(seconds: 3));
  await tester.pump();
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  WidgetController.hitTestWarningShouldBeFatal = true;
  testWidgets(
    'L46/47 Android real: lists, import, invitation, two-session changes, revoke and matching integration',
    (tester) async {
      const config = AppConfig.fromEnvironment();
      if (!config.allowLocalBackend ||
          config.supabaseUrl != 'http://10.0.2.2:54321') {
        throw StateError('Only isolated emulator backend permitted');
      }
      final suffix = newRecipeRequestId().replaceAll('-', '').substring(0, 10),
          password = 'P7-native-${newRecipeRequestId()}!';
      final emails = {
        for (final letter in ['a', 'b', 'c'])
          letter: 'mixtick-p7-native-$suffix-$letter@example.test',
      };
      final creator = SupabaseClient(
        config.supabaseUrl,
        config.publishableKey,
        authOptions: const AuthClientOptions(
          authFlowType: AuthFlowType.implicit,
          autoRefreshToken: false,
        ),
      );
      String? privateId, publicId;
      for (final letter in ['a', 'b', 'c']) {
        final result = await creator.auth.signUp(
          email: emails[letter]!,
          password: password,
        );
        expect(result.session, isNotNull);
        debugPrint(
          'P7_FIXTURE:${jsonEncode({'id': result.user!.id, 'email': emails[letter]})}',
        );
        await creator.from('profiles').insert({
          'username': 'p7n_${suffix}_$letter',
          'display_name': letter == 'a'
              ? 'Cocina de Ana'
              : 'Compra ${letter.toUpperCase()}',
        });
        if (letter == 'a') {
          final recipes = SupabaseRecipeRepository(creator);
          privateId = await recipes.save(
            const RecipeDraft(
              title: 'Receta privada de Ana',
              category: 'Principal',
              servings: 2.5,
              ingredients: [
                RecipeIngredient(
                  ingredientId: '10000000-0000-4000-8000-000000000004',
                  name: 'Huevo',
                  quantity: 1.25,
                  unit: 'ud',
                ),
                RecipeIngredient(
                  customName: 'Miso blanco',
                  name: 'Miso blanco',
                  quantity: 2.5,
                  unit: 'g',
                ),
                RecipeIngredient(
                  ingredientId: '10000000-0000-4000-8000-000000000008',
                  name: 'Sal',
                  quantity: 0.125,
                  unit: 'g',
                  optional: true,
                ),
              ],
              steps: ['Mezclar los ingredientes.'],
            ),
            requestId: newRecipeRequestId(),
          );
          publicId = await recipes.save(
            const RecipeDraft(
              title: 'Huevos con patatas',
              category: 'Principal',
              servings: 2,
              ingredients: [
                RecipeIngredient(
                  ingredientId: '10000000-0000-4000-8000-000000000004',
                  name: 'Huevo',
                  quantity: 2,
                  unit: 'ud',
                ),
                RecipeIngredient(
                  ingredientId: '10000000-0000-4000-8000-000000000003',
                  name: 'Patata',
                  quantity: 0.5,
                  unit: 'kg',
                ),
              ],
              steps: ['Preparar y cocinar.'],
            ),
            requestId: newRecipeRequestId(),
          );
          await recipes.setVisibility(
            (await recipes.read(publicId))!,
            RecipeVisibility.public,
          );
        }
      }
      await creator.auth.signInWithPassword(
        email: emails['a']!,
        password: password,
      );
      final owner = SupabaseShoppingRepository(creator);
      final container = await mountNative(tester, config);
      await shopTap(tester, find.text('Iniciar sesión').first);
      await submitNative(tester, emails['a']!, password);
      await until(
        tester,
        () => find.byType(NavigationDestination).evaluate().length == 4,
      );
      await shopTap(tester, find.byKey(const ValueKey(AppModule.shopping)));
      await shopTap(tester, find.byKey(const ValueKey('shop-create-list')));
      await tester.enterText(
        find.byKey(const ValueKey('shop-editor-name')),
        'Compra de la semana',
      );
      await shopTap(tester, find.byKey(const ValueKey('shop-editor-save')));
      await until(
        tester,
        () => find.text('Compra de la semana').evaluate().isNotEmpty,
      );
      final listId = (await owner.overview()).lists.single.id;
      await shopTap(tester, find.byKey(ValueKey('shop-list-$listId')));
      await until(
        tester,
        () => find
            .byKey(const ValueKey('shop-quick-input'))
            .evaluate()
            .isNotEmpty,
      );
      await tester.enterText(
        find.byKey(const ValueKey('shop-quick-input')),
        'Jabón',
      );
      await shopTap(tester, find.byKey(const ValueKey('shop-quick-add')));
      await until(tester, () => find.text('Jabón').evaluate().isNotEmpty);
      var item = (await owner.read(listId)).items.single;
      await shopTap(tester, find.byKey(ValueKey('shop-edit-${item.id}')));
      await tester.enterText(
        find.byKey(const ValueKey('shop-editor-quantity')),
        '0,125',
      );
      await tester.enterText(
        find.byKey(const ValueKey('shop-editor-unit')),
        'l',
      );
      await shopTap(tester, find.byKey(const ValueKey('shop-editor-save')));
      await until(tester, () => find.text('0,125 l').evaluate().isNotEmpty);
      item = (await owner.read(listId)).items.single;
      expect(item.quantity, 0.125);
      await shopTap(tester, find.byKey(ValueKey('shop-check-${item.id}')));
      await until(
        tester,
        () => find.byKey(ValueKey('shop-check-${item.id}')).evaluate().isEmpty,
      );
      await shopTap(tester, find.byKey(const ValueKey('shop-bought')));
      await until(tester, () => find.text('Jabón').evaluate().isNotEmpty);
      container.read(routerProvider).push('/recipes/$privateId');
      await tester.pump();
      await until(
        tester,
        () => find
            .byKey(const ValueKey('shop-import-recipe'))
            .evaluate()
            .isNotEmpty,
      );
      await shopTap(tester, find.byKey(const ValueKey('shop-import-recipe')));
      await until(
        tester,
        () => find
            .byKey(const ValueKey('shop-destination'))
            .evaluate()
            .isNotEmpty,
      );
      await shopTap(tester, find.byKey(const ValueKey('shop-destination')));
      await shopTap(tester, find.text('Compra de la semana').last);
      await shoppingShot(tester, 'shopping-selection');
      await shopTap(tester, find.byKey(const ValueKey('shop-import-confirm')));
      await until(
        tester,
        () => find
            .byKey(const ValueKey('shop-open-destination'))
            .evaluate()
            .isNotEmpty,
      );
      expect((await owner.read(listId)).items.length, 4);
      await shopTap(
        tester,
        find.byKey(const ValueKey('shop-open-destination')),
      );
      await until(
        tester,
        () => find.byType(ShoppingDetailPage).evaluate().isNotEmpty,
      );
      await shopTap(tester, find.byKey(const ValueKey('shop-invite')));
      await tester.enterText(
        find.byKey(const ValueKey('shop-editor-name')),
        'p7n_${suffix}_b',
      );
      await shopTap(tester, find.byKey(const ValueKey('shop-editor-save')));
      await until(
        tester,
        () => find.text('Invitación pendiente').evaluate().isNotEmpty,
      );
      await container
          .read(authControllerProvider.notifier)
          .execute((repo) => repo.signOut());
      await tester.pump();
      await until(
        tester,
        () => find.text('Iniciar sesión').evaluate().isNotEmpty,
      );
      await shopTap(tester, find.text('Iniciar sesión').first);
      await submitNative(tester, emails['b']!, password);
      await until(
        tester,
        () => find.byType(NavigationDestination).evaluate().length == 4,
      );
      await shopTap(tester, find.byKey(const ValueKey(AppModule.shopping)));
      await until(tester, () => find.text('Aceptar').evaluate().isNotEmpty);
      await shopTap(tester, find.text('Aceptar'));
      await until(
        tester,
        () => find.byKey(ValueKey('shop-list-$listId')).evaluate().isNotEmpty,
      );
      await shopTap(tester, find.byKey(ValueKey('shop-list-$listId')));
      await until(
        tester,
        () =>
            container.read(shoppingDetailProvider(listId)).value?.signal ==
            ShoppingSignal.connected,
      );
      final rt = await owner.add(
        listId,
        const ShoppingDraft('Pan compartido', quantity: 2, unit: 'ud'),
        newRecipeRequestId(),
      );
      await until(
        tester,
        () => find.text('Pan compartido').evaluate().isNotEmpty,
        seconds: 5,
      );
      expect(find.text('Receta privada de Ana'), findsNothing);
      expect(find.byKey(const ValueKey('shop-invite')), findsNothing);
      await shoppingShot(tester, 'shopping-light');
      await shoppingShot(tester, 'shopping-dark');
      await shopTap(tester, find.byKey(ValueKey('shop-check-$rt')));
      await until(
        tester,
        () => find.byKey(ValueKey('shop-check-$rt')).evaluate().isEmpty,
      );
      expect(
        (await owner.read(listId)).items
            .singleWhere((i) => i.id == rt)
            .purchased,
        isTrue,
      );
      final before = (await owner.read(listId)).items.length;
      container.read(routerProvider).go('/cook-today');
      await tester.pump();
      await until(
        tester,
        () => find.byType(CookTodayPage).evaluate().isNotEmpty,
      );
      await tester.enterText(
        find.byKey(const ValueKey('matching-input')),
        'Huevos',
      );
      await until(
        tester,
        () => find
            .byKey(
              const ValueKey('suggestion-10000000-0000-4000-8000-000000000004'),
            )
            .evaluate()
            .isNotEmpty,
      );
      await shopTap(
        tester,
        find.byKey(
          const ValueKey('suggestion-10000000-0000-4000-8000-000000000004'),
        ),
      );
      await shopTap(tester, find.byKey(const ValueKey('matching-near')));
      await until(
        tester,
        () =>
            container
                .read(
                  matchingPagesProvider(
                    MatchingQuery([
                      const SelectedIngredient(
                        id: '10000000-0000-4000-8000-000000000004',
                        name: 'Huevo',
                      ),
                    ], MatchingMode.near),
                  ),
                )
                .value
                ?.matches
                .isNotEmpty ==
            true,
      );
      await shopTap(tester, find.byKey(ValueKey('match-open-$publicId')));
      await shopTap(tester, find.byKey(const ValueKey('shop-import-missing')));
      await until(
        tester,
        () =>
            find.byType(ShoppingImportPage).evaluate().isNotEmpty &&
            find
                .byKey(const ValueKey('shop-destination'))
                .evaluate()
                .isNotEmpty,
      );
      expect(find.text('Patata'), findsOneWidget);
      expect(find.text('Huevo'), findsNothing);
      await shopTap(tester, find.byKey(const ValueKey('shop-destination')));
      await shopTap(tester, find.text('Compra de la semana').last);
      await shopTap(tester, find.byKey(const ValueKey('shop-import-confirm')));
      await until(
        tester,
        () => find
            .byKey(const ValueKey('shop-open-destination'))
            .evaluate()
            .isNotEmpty,
      );
      final actual = await owner.read(listId);
      expect(actual.items.length, before + 1);
      expect(
        actual.items.where((i) => i.name == 'Patata').single.quantity,
        0.5,
      );
      await shopTap(
        tester,
        find.byKey(const ValueKey('shop-open-destination')),
      );
      await until(
        tester,
        () =>
            container.read(shoppingDetailProvider(listId)).value?.snapshot !=
            null,
      );
      final member = (await owner.read(listId)).members.single;
      await owner.revoke(listId, member.id);
      await until(
        tester,
        () => find.byKey(const ValueKey('shop-quick-input')).evaluate().isEmpty,
        seconds: 20,
      );
      expect(find.text('Patata'), findsNothing);
      await container
          .read(authControllerProvider.notifier)
          .execute((repo) => repo.signOut());
      await tester.pump();
      await until(
        tester,
        () => find.text('Iniciar sesión').evaluate().isNotEmpty,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
      await creator.dispose();
    },
    timeout: const Timeout(Duration(minutes: 8)),
  );
}
