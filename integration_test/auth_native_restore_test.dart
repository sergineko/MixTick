// Second independent Android process: restore, persistence, logout/login, recovery.
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mixtick/core/config/app_config.dart';
import 'package:mixtick/features/auth/data/secure_auth_storage.dart';
import 'package:mixtick/features/auth/presentation/auth_providers.dart';
import 'package:mixtick/features/profile/presentation/profile_providers.dart';

import 'native_test_helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Android real: arranque independiente restaura sesión, perfil y salida efectiva',
    (tester) async {
      const config = AppConfig.fromEnvironment();
      final storage = SecureAuthStorage(config.supabaseUrl);
      final saved = await storage.read('native-fixture');
      expect(saved != null, isTrue, reason: 'Run the native seed test first');
      final fixture = jsonDecode(saved!) as Map<String, dynamic>;
      final container = await mountNative(tester, config);
      await until(
        tester,
        () => find.byType(NavigationDestination).evaluate().length == 4,
      );
      final session = await container.read(authSessionProvider.future);
      expect(session!.userId, fixture['id']);
      final profile = await container.read(ownProfileProvider.future);
      expect(profile!.username, fixture['username']);
      await nativeTap(tester, find.byTooltip('Mi perfil'));
      await until(
        tester,
        () => find.text('Cerrar sesión').evaluate().isNotEmpty,
      );
      await nativeTap(tester, find.text('Cerrar sesión'));
      await until(
        tester,
        () => find.text('Tu cocina, en un solo lugar').evaluate().isNotEmpty,
      );
      // Server logout response can arrive after the immediate SDK local clear.
      await tester.pump(const Duration(seconds: 1));
      expect(await storage.hasAccessToken(), isFalse);
      await nativeTap(tester, find.text('Iniciar sesión'));
      await submitNative(
        tester,
        fixture['email'] as String,
        'wrong-native-password',
      );
      await until(
        tester,
        () => find
            .textContaining('No pudimos iniciar sesión con esos datos')
            .evaluate()
            .isNotEmpty,
      );
      expect(find.byType(NavigationDestination), findsNothing);
      await submitNative(
        tester,
        fixture['email'] as String,
        fixture['password'] as String,
      );
      await until(
        tester,
        () => find.byType(NavigationDestination).evaluate().length == 4,
      );
      await nativeTap(tester, find.byTooltip('Mi perfil'));
      await until(
        tester,
        () => find.text('Cerrar sesión').evaluate().isNotEmpty,
      );
      await nativeTap(tester, find.text('Cerrar sesión'));
      await until(
        tester,
        () => find.text('Tu cocina, en un solo lugar').evaluate().isNotEmpty,
      );
      await tester.pump(const Duration(seconds: 1));
      await nativeTap(tester, find.text('Iniciar sesión'));
      await nativeTap(tester, find.text('He olvidado mi contraseña'));
      await tester.enterText(
        find.byKey(const ValueKey('email')),
        fixture['email'] as String,
      );
      await nativeTap(tester, find.byKey(const ValueKey('submit-auth')));
      await until(
        tester,
        () => find
            .textContaining('Si el correo corresponde a una cuenta')
            .evaluate()
            .isNotEmpty,
      );
      // Host runner delivers the real Mailpit PKCE callback via Android ACTION_VIEW.
      // Only this random fixture address is printed for selecting its local email.
      // ignore: avoid_print
      print('MIXTICK_RECOVERY_READY:${fixture['email']}');
      await until(
        tester,
        () =>
            find.byKey(const ValueKey('repeat-password')).evaluate().isNotEmpty,
        seconds: 120,
      );
      expect(find.byType(NavigationDestination), findsNothing);
      final newPassword =
          'Native-updated-${Random.secure().nextInt(1 << 32)}-safe!';
      await tester.enterText(
        find.byKey(const ValueKey('password')),
        newPassword,
      );
      await tester.enterText(
        find.byKey(const ValueKey('repeat-password')),
        newPassword,
      );
      await nativeTap(tester, find.byKey(const ValueKey('submit-auth')));
      await until(
        tester,
        () =>
            container.read(authSessionProvider).value?.requiresPasswordChange ==
            false,
      );
      await container.read(authRepositoryProvider)!.signOut();
      await until(
        tester,
        () => find.text('Tu cocina, en un solo lugar').evaluate().isNotEmpty,
      );
      await tester.pump(const Duration(seconds: 1));
      expect(await storage.hasAccessToken(), isFalse);
      await storage.remove('native-fixture');
      await tester.pump(const Duration(seconds: 1));
      expect(await storage.read('native-fixture') == null, isTrue);
      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
    },
  );
}
