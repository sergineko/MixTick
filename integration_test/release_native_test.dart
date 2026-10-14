// Real Android account UI, encrypted session cleanup and server worker.
// Host companion triggers the authenticated worker; no admin key in this app.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:image/image.dart' as img;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mixtick/core/config/app_config.dart';
import 'package:mixtick/features/auth/data/secure_auth_storage.dart';
import 'package:mixtick/features/auth/presentation/auth_providers.dart';
import 'package:mixtick/features/recipes/data/supabase_recipe_repository.dart';
import 'package:mixtick/features/recipes/domain/recipe.dart';
import 'package:mixtick/features/recipes/domain/recipe_repository.dart';

import 'native_test_helpers.dart';

Future<void> tapRelease(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      finder,
      160,
      scrollable: find.byType(Scrollable).first,
    );
  }
  await Scrollable.ensureVisible(tester.element(finder), alignment: 0.5);
  await tester.pump(const Duration(milliseconds: 300));
  await tester.tap(finder);
  await tester.pump(const Duration(milliseconds: 400));
}

Future<void> releaseShot(WidgetTester tester, String name) async {
  await tester.pump(const Duration(milliseconds: 600));
  debugPrint('P8_SCREEN:$name');
  await Future<void>.delayed(const Duration(seconds: 3));
  await tester.pump();
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  WidgetController.hitTestWarningShouldBeFatal = true;
  testWidgets(
    'D12 Android: explicit account deletion, real physical worker and encrypted session cleared',
    (tester) async {
      const config = AppConfig.fromEnvironment();
      final suffix = newRecipeRequestId().replaceAll('-', '').substring(0, 10);
      final password = 'Native-p8-${newRecipeRequestId()}!';
      final email = 'mixtick-p8-native-$suffix-a@example.test';
      final creator = SupabaseClient(
        config.supabaseUrl,
        config.publishableKey,
        authOptions: const AuthClientOptions(
          autoRefreshToken: false,
          authFlowType: AuthFlowType.implicit,
        ),
      );
      final registered = await creator.auth.signUp(
        email: email,
        password: password,
      );
      final uid = registered.user!.id;
      debugPrint('P8_FIXTURE:${jsonEncode({'id': uid, 'email': email})}');
      await creator.from('profiles').insert({
        'username': 'p8n_${suffix}_a',
        'display_name': 'Cuenta de auditoría',
      });
      final repo = SupabaseRecipeRepository(creator);
      final rid = await repo.save(
        const RecipeDraft(
          title: 'Receta privada a eliminar',
          category: 'Prueba',
          servings: 1,
          ingredients: [
            RecipeIngredient(customName: 'Ingrediente', name: 'Ingrediente'),
          ],
          steps: ['Preparar.'],
        ),
        requestId: newRecipeRequestId(),
      );
      final recipe = (await repo.read(rid))!;
      final bytes = img.encodePng(
        img.Image(width: 16, height: 16)..clear(img.ColorRgb8(180, 100, 35)),
      );
      final path = await repo.uploadPhoto(recipe, bytes, PhotoCancellation());
      await repo.setPhoto(recipe, path);
      final container = await mountNative(tester, config);
      await tapRelease(tester, find.text('Iniciar sesión').first);
      await submitNative(tester, email, password);
      await until(
        tester,
        () => find.byType(NavigationDestination).evaluate().length == 4,
      );
      expect(
        await SecureAuthStorage(config.supabaseUrl).hasAccessToken(),
        true,
      );
      await tapRelease(tester, find.byTooltip('Mi perfil'));
      await tapRelease(tester, find.byKey(const ValueKey('account-deletion')));
      await releaseShot(tester, 'account-delete-light');
      await releaseShot(tester, 'account-delete-dark');
      await tapRelease(
        tester,
        find.byKey(const ValueKey('delete-account-agree')),
      );
      final pass = find.byKey(const ValueKey('delete-account-password'));
      await tapRelease(tester, pass);
      await tester.enterText(pass, password);
      final confirm = find.byKey(const ValueKey('delete-account-confirm'));
      await tapRelease(tester, confirm);
      await tester.enterText(confirm, 'ELIMINAR');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await Scrollable.ensureVisible(
        tester.element(find.byKey(const ValueKey('delete-account-submit'))),
        alignment: 0.5,
      );
      await releaseShot(tester, 'account-delete-enabled');
      await tapRelease(
        tester,
        find.byKey(const ValueKey('delete-account-submit')),
      );
      await until(
        tester,
        () => find.text('Tu cocina, en un solo lugar').evaluate().isNotEmpty,
      );
      expect(container.read(authSessionProvider).value, isNull);
      await until(
        tester,
        () => find.byType(NavigationDestination).evaluate().isEmpty,
      );
      expect(
        await SecureAuthStorage(config.supabaseUrl).hasAccessToken(),
        false,
      );
      debugPrint('P8_WORKER_REQUIRED');
      await Future<void>.delayed(const Duration(seconds: 5));
      await expectLater(creator.auth.getUser(), throwsA(isA<AuthException>()));
      await releaseShot(tester, 'account-deleted-session');
      debugPrint(
        'P8_DONE: account UI + Auth removal + native encrypted session absent',
      );
      await creator.dispose();
      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
