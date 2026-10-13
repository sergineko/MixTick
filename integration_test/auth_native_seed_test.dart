// First Android process: real UI registration/profile, persisted encrypted session.
// Run before auth_native_restore_test.dart. Only random local fixture accounts.
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
    'Android real: registro UI, perfil propio y sesión cifrada para siguiente proceso',
    (tester) async {
      const config = AppConfig.fromEnvironment();
      final storage = SecureAuthStorage(config.supabaseUrl);
      final previousFixture = await storage.read('native-fixture');
      if (previousFixture != null) {
        // Reclaim only this test's encrypted marker, never an unrelated account.
        final previous = jsonDecode(previousFixture) as Map<String, dynamic>;
        expect(
          RegExp(r'^mixtick-native-[0-9a-f]{1,8}@example\.test$')
              .hasMatch(previous['email'] as String),
          isTrue,
        );
        expect(
          RegExp(r'^[0-9a-f-]{36}$').hasMatch(previous['id'] as String),
          isTrue,
        );
        final oldSession = await storage.accessToken();
        if (oldSession != null) {
          expect(
            (jsonDecode(oldSession) as Map<String, dynamic>)['user']['id'],
            previous['id'],
          );
        }
        // ignore: avoid_print
        print('MIXTICK_FIXTURE_ID:${previous['id']}');
        await storage.remove('native-fixture');
        await storage.removePersistedSession();
        await tester.pump(const Duration(seconds: 1));
      }
      final container = await mountNative(tester, config);
      final suffix = Random.secure().nextInt(1 << 32).toRadixString(16);
      final email = 'mixtick-native-$suffix@example.test';
      final password = 'Native-${Random.secure().nextInt(1 << 32)}-safe!';
      final username = 'native_$suffix';
      await nativeTap(tester, find.text('Crear cuenta'));
      await submitNative(tester, email, password, repeat: true);
      await until(
        tester,
        () => find.byType(NavigationDestination).evaluate().length == 4,
      );
      final session = container.read(authSessionProvider).value!;
      // ID alone allows host-side scoped fixture cleanup; no email/password/token printed.
      // ignore: avoid_print
      print('MIXTICK_FIXTURE_ID:${session.userId}');
      await storage.write(
        'native-fixture',
        jsonEncode({
          'id': session.userId,
          'email': email,
          'password': password,
          'username': username,
        }),
      );
      await nativeTap(tester, find.byTooltip('Mi perfil'));
      await until(
        tester,
        () => find.text('Crear mi perfil').evaluate().isNotEmpty,
      );
      await nativeTap(tester, find.text('Crear mi perfil'));
      await until(
        tester,
        () => find.byKey(const ValueKey('username')).evaluate().isNotEmpty,
      );
      await tester.enterText(
        find.byKey(const ValueKey('display-name')),
        'Perfil Android',
      );
      await tester.enterText(
        find.byKey(const ValueKey('username')),
        username.toUpperCase(),
      );
      await nativeTap(tester, find.byKey(const ValueKey('save-profile')));
      await until(tester, () => find.text('@$username').evaluate().isNotEmpty);
      final profile = await container.read(ownProfileProvider.future);
      expect(profile!.username, username);
      expect(profile.userId, session.userId);
      await nativeTap(tester, find.text('Ver mi perfil público'));
      await until(
        tester,
        () => find.text('Perfil público').evaluate().isNotEmpty,
      );
      expect(find.text(email).evaluate().isEmpty, isTrue);
      await until(tester, () => find.text('@$username').evaluate().isNotEmpty);
      final persisted = await storage.accessToken();
      expect(persisted != null, isTrue);
      expect(
        (jsonDecode(persisted!) as Map<String, dynamic>)['user']['id'],
        session.userId,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
      // Deliberately retain this fixture/session for the next, independent APK launch.
    },
  );
}
