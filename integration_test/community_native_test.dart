// Android UI with real local Auth/PostgREST/Storage. No repository overrides.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:image/image.dart' as img;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mixtick/app/router.dart';
import 'package:mixtick/core/config/app_config.dart';
import 'package:mixtick/features/auth/presentation/auth_controller.dart';
import 'package:mixtick/features/community/data/supabase_community_repository.dart';
import 'package:mixtick/features/community/domain/community.dart';
import 'package:mixtick/features/community/presentation/community_providers.dart';
import 'package:mixtick/features/community/presentation/community_widgets.dart';
import 'package:mixtick/features/profile/data/supabase_profile_repository.dart';
import 'package:mixtick/features/recipes/data/supabase_recipe_repository.dart';
import 'package:mixtick/features/recipes/domain/recipe.dart';
import 'package:mixtick/features/recipes/domain/recipe_repository.dart';
import 'package:mixtick/features/recipes/presentation/recipe_detail_page.dart';
import 'package:mixtick/features/recipes/presentation/recipe_providers.dart';
import 'package:mixtick/shared/models/app_module.dart';

import 'native_test_helpers.dart';

Future<void> socialTap(WidgetTester tester, Finder finder) async {
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

Future<void> communityShot(WidgetTester tester, String name) async {
  await tester.pump(const Duration(milliseconds: 800));
  await Future<void>.delayed(const Duration(milliseconds: 500));
  await tester.pump();
  debugPrint('P5_SCREEN:$name');
  await Future<void>.delayed(const Duration(seconds: 3));
  await tester.pump();
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  WidgetController.hitTestWarningShouldBeFatal = true;
  testWidgets(
    'C32 Android real: community, likes, saved, comments, follow, report, blocks, privatization and A/B isolation',
    (tester) async {
      const config = AppConfig.fromEnvironment();
      if (!config.allowLocalBackend ||
          config.supabaseUrl != 'http://10.0.2.2:54321') {
        throw StateError('Only isolated local emulator endpoint allowed');
      }
      final suffix = newRecipeRequestId().replaceAll('-', '').substring(0, 10),
          password = 'P5-native-${newRecipeRequestId()}!';
      final emails = {
        for (final letter in ['a', 'b', 'c'])
          letter: 'mixtick-p5-native-$suffix-$letter@example.test',
      };
      final creator = SupabaseClient(
        config.supabaseUrl,
        config.publishableKey,
        authOptions: const AuthClientOptions(
          authFlowType: AuthFlowType.implicit,
          autoRefreshToken: false,
        ),
      );
      final ids = <String, String>{};
      String? recipeId, privateId;
      final image = img.Image(width: 800, height: 600)
        ..clear(img.ColorRgb8(235, 225, 200));
      img.fillCircle(
        image,
        x: 400,
        y: 300,
        radius: 240,
        color: img.ColorRgb8(245, 245, 245),
      );
      img.fillCircle(
        image,
        x: 400,
        y: 300,
        radius: 205,
        color: img.ColorRgb8(200, 80, 50),
      );
      for (var i = 0; i < 8; i++) {
        img.fillCircle(
          image,
          x: 280 + (i % 4) * 80,
          y: 220 + (i ~/ 4) * 120,
          radius: 25,
          color: img.ColorRgb8(55, 130, 65),
        );
      }
      for (final letter in ['a', 'b', 'c']) {
        final response = await creator.auth.signUp(
          email: emails[letter]!,
          password: password,
        );
        expect(response.session, isNotNull);
        ids[letter] = response.user!.id;
        debugPrint(
          'P5_FIXTURE:${jsonEncode({'id': response.user!.id, 'email': emails[letter]})}',
        );
        final profiles = SupabaseProfileRepository(creator);
        final profile = await profiles.save(
          username: 'p5n_${suffix}_$letter',
          displayName: letter == 'a'
              ? 'Cocina de prueba'
              : 'Prueba Android ${letter.toUpperCase()}',
        );
        if (letter == 'a') {
          final avatar = await profiles.uploadAvatar(img.encodePng(image));
          await profiles.save(
            username: profile.username,
            displayName: profile.displayName,
            previous: profile,
            avatarPath: avatar,
          );
          final recipes = SupabaseRecipeRepository(creator);
          const draft = RecipeDraft(
            title: 'Sopa de tomates · Comunidad',
            category: 'Entrante',
            description:
                'Receta controlada para verificar Comunidad en Android.',
            servings: 2,
            prepMinutes: 10,
            cookMinutes: 20,
            ingredients: [
              RecipeIngredient(
                ingredientId: '10000000-0000-4000-8000-000000000001',
                name: 'Tomate',
                quantity: 1,
                unit: 'kg',
              ),
              RecipeIngredient(
                ingredientId: '10000000-0000-4000-8000-000000000008',
                name: 'Sal',
                optional: true,
              ),
            ],
            steps: ['Cocer los tomates.', 'Triturar y servir.'],
          );
          recipeId = await recipes.save(draft, requestId: newRecipeRequestId());
          var recipe = (await recipes.read(recipeId))!;
          final path = await recipes.uploadPhoto(
            recipe,
            img.encodePng(image),
            PhotoCancellation(),
          );
          await recipes.setPhoto(recipe, path);
          recipe = (await recipes.read(recipeId))!;
          await recipes.setVisibility(recipe, RecipeVisibility.public);
          privateId = await recipes.save(
            const RecipeDraft(
              title: 'Privada de A · no mostrar',
              category: 'Privada',
              servings: 1,
              ingredients: [
                RecipeIngredient(customName: 'Privado', name: 'Privado'),
              ],
              steps: ['Privado'],
            ),
            requestId: newRecipeRequestId(),
          );
        }
      }
      await creator.auth.signInWithPassword(
        email: emails['c']!,
        password: password,
      );
      await SupabaseCommunityRepository(creator).comment(
        recipeId!,
        'Comentario de C para denuncia',
        newRecipeRequestId(),
      );
      final container = await mountNative(tester, config);
      expect(find.text('Tu cocina, en un solo lugar'), findsOneWidget);
      await socialTap(tester, find.text('Iniciar sesión').first);
      await submitNative(tester, emails['b']!, password);
      await until(
        tester,
        () => find.byType(NavigationDestination).evaluate().length == 4,
      );
      await until(
        tester,
        () => find.byType(CommunityRecipeCard).evaluate().isNotEmpty,
      );
      expect(find.text('Privada de A · no mostrar'), findsNothing);
      final id = recipeId;
      final repo = container.read(communityRepositoryProvider)!;
      await socialTap(tester, find.byKey(ValueKey('like-$id')));
      await until(
        tester,
        () =>
            container
                .read(communityPagesProvider(const CommunityQuery()))
                .value
                ?.entries
                .firstOrNull
                ?.liked ==
            true,
      );
      await socialTap(tester, find.byKey(ValueKey('save-$id')));
      await until(
        tester,
        () =>
            container
                .read(communityPagesProvider(const CommunityQuery()))
                .value
                ?.entries
                .firstOrNull
                ?.saved ==
            true,
      );
      expect((await repo.entry(id))!.likes, 1);
      final feedScroll = tester.state<ScrollableState>(
        find.byType(Scrollable).first,
      );
      feedScroll.position.jumpTo(120);
      await tester.pump();
      await until(
        tester,
        () => find
            .byWidgetPredicate((w) => w is Image && w.height == 210)
            .evaluate()
            .isNotEmpty,
      );
      await communityShot(tester, 'community-light');
      await until(
        tester,
        () =>
            Theme.of(tester.element(find.byType(CommunityRecipeCard).first))
                .brightness ==
            Brightness.dark,
      );
      await communityShot(tester, 'community-dark');
      await until(
        tester,
        () =>
            Theme.of(tester.element(find.byType(CommunityRecipeCard).first))
                .brightness ==
            Brightness.light,
      );
      await socialTap(tester, find.byKey(const ValueKey(AppModule.recipes)));
      await socialTap(tester, find.text('Guardadas'));
      await until(
        tester,
        () => find.byType(CommunityRecipeCard).evaluate().isNotEmpty,
      );
      await communityShot(tester, 'saved-header');
      final savedScroll = tester.state<ScrollableState>(
        find.byType(Scrollable).first,
      );
      savedScroll.position.jumpTo(180);
      await tester.pump();
      await until(
        tester,
        () => find
            .byWidgetPredicate((w) => w is Image && w.height == 210)
            .evaluate()
            .isNotEmpty,
      );
      await communityShot(tester, 'saved-recipes');
      await socialTap(tester, find.byKey(ValueKey('open-$id')));
      await until(
        tester,
        () =>
            find.byType(RecipeDetailPage).evaluate().isNotEmpty &&
            find.byKey(ValueKey('comments-$id')).evaluate().isNotEmpty,
      );
      expect(
        tester.widget<RecipeDetailPage>(find.byType(RecipeDetailPage)).id,
        id,
      );
      expect(find.byKey(const ValueKey('edit-recipe')), findsNothing);
      expect(find.text('Guardada'), findsOneWidget);
      await socialTap(tester, find.byKey(ValueKey('comments-$id')));
      await until(
        tester,
        () => find.byKey(const ValueKey('comment-input')).evaluate().isNotEmpty,
      );
      await tester.enterText(
        find.byKey(const ValueKey('comment-input')),
        'Comentario real de Android',
      );
      await socialTap(tester, find.byKey(const ValueKey('send-comment')));
      await until(
        tester,
        () =>
            container
                .read(commentsProvider(id))
                .value
                ?.comments
                .any((c) => c.content == 'Comentario real de Android') ==
            true,
      );
      final own = (await repo.comments(id)).comments
          .singleWhere((c) => c.authorId == ids['b']);
      await socialTap(tester, find.byKey(ValueKey('delete-comment-${own.id}')));
      await socialTap(
        tester,
        find.widgetWithText(FilledButton, 'Eliminar comentario'),
      );
      await until(
        tester,
        () =>
            container
                .read(commentsProvider(id))
                .value
                ?.comments
                .any((c) => c.id == own.id) ==
            false,
      );
      container.read(routerProvider).go('/people/p5n_${suffix}_a');
      await tester.pump();
      await until(
        tester,
        () => find.byKey(const ValueKey('follow-author')).evaluate().isNotEmpty,
      );
      await socialTap(tester, find.byKey(const ValueKey('follow-author')));
      await until(
        tester,
        () =>
            container
                .read(socialAuthorProvider('p5n_${suffix}_a'))
                .value
                ?.followed ==
            true,
      );
      await socialTap(tester, find.byKey(const ValueKey('report-profile')));
      await socialTap(
        tester,
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(DropdownButtonFormField<String>),
        ),
      );
      await socialTap(tester, find.text('Publicidad o spam repetido').last);
      await socialTap(tester, find.text('Enviar denuncia'));
      await until(
        tester,
        () => find.text('Denuncia enviada').evaluate().isNotEmpty,
      );
      await socialTap(tester, find.text('Cerrar'));
      await socialTap(tester, find.byKey(const ValueKey('block-author')));
      await socialTap(
        tester,
        find.widgetWithText(FilledButton, 'Bloquear cuenta'),
      );
      await until(
        tester,
        () =>
            find.text('Este perfil no está disponible.').evaluate().isNotEmpty,
      );
      expect(await repo.author('p5n_${suffix}_a'), isNull);
      container.read(routerProvider).go('/community/blocked');
      await tester.pump();
      await until(
        tester,
        () => find.byTooltip('Desbloquear cuenta').evaluate().isNotEmpty,
      );
      await socialTap(tester, find.byTooltip('Desbloquear cuenta'));
      await until(
        tester,
        () => container.read(blockedAuthorsProvider).value?.isEmpty == true,
      );
      expect(await repo.author('p5n_${suffix}_a'), isNotNull);
      // Server privatizes independently while B retains a saved reference.
      await creator.auth.signInWithPassword(
        email: emails['a']!,
        password: password,
      );
      final ar = SupabaseRecipeRepository(creator);
      await ar.setVisibility((await ar.read(id))!, RecipeVisibility.private);
      container.read(routerProvider).go('/recipes/$id');
      container.invalidate(recipeDetailProvider(id));
      await tester.pump();
      await until(
        tester,
        () => find
            .text('Esta receta no está disponible para tu cuenta.')
            .evaluate()
            .isNotEmpty,
      );
      expect(find.text('Triturar y servir.'), findsNothing);
      expect(await repo.entry(id), isNull);
      expect(
        await container.read(recipeRepositoryProvider)!.read(privateId!),
        isNull,
      );
      // Drafts and visible data cannot carry across actual native Auth sessions.
      await ar.setVisibility((await ar.read(id))!, RecipeVisibility.public);
      container.read(routerProvider).go('/recipes/$id/comments');
      container.invalidate(recipeDetailProvider(id));
      await tester.pump();
      await until(
        tester,
        () => find.byKey(const ValueKey('comment-input')).evaluate().isNotEmpty,
      );
      await tester.enterText(
        find.byKey(const ValueKey('comment-input')),
        'Borrador privado de B',
      );
      await container
          .read(authControllerProvider.notifier)
          .execute((auth) => auth.signOut());
      await until(
        tester,
        () => find.text('Tu cocina, en un solo lugar').evaluate().isNotEmpty,
      );
      expect(find.byKey(const ValueKey('comment-input')), findsNothing);
      await socialTap(tester, find.text('Iniciar sesión').first);
      await submitNative(tester, emails['a']!, password);
      await until(
        tester,
        () => find.byType(NavigationDestination).evaluate().length == 4,
      );
      expect(
        (await container
                .read(communityRepositoryProvider)!
                .load(const CommunityQuery(saved: true)))
            .entries,
        isEmpty,
      );
      container.read(routerProvider).go('/recipes/$id/comments');
      await tester.pump();
      await until(
        tester,
        () => find.byKey(const ValueKey('comment-input')).evaluate().isNotEmpty,
      );
      expect(
        tester
            .widget<TextFormField>(find.byKey(const ValueKey('comment-input')))
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
      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
      await creator.dispose();
    },
  );
}
