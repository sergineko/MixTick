import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mixtick/app/app.dart';
import 'package:mixtick/app/router.dart';
import 'package:mixtick/core/config/app_config.dart';
import 'package:mixtick/features/auth/domain/auth_failure.dart';
import 'package:mixtick/features/auth/domain/auth_session.dart';
import 'package:mixtick/features/auth/domain/auth_validation.dart';
import 'package:mixtick/features/auth/presentation/auth_providers.dart';
import 'package:mixtick/features/profile/domain/profile_repository.dart';
import 'package:mixtick/features/profile/domain/user_profile.dart';
import 'package:mixtick/features/profile/presentation/profile_providers.dart';

import '../support/fake_repositories.dart';

import 'package:mixtick/features/auth/presentation/auth_controller.dart';

Future<ProviderContainer> mount(
  WidgetTester tester,
  FakeAuthRepository auth, {
  String path = '/access/login',
  FakeProfileRepository? profiles,
}) async {
  final container = ProviderContainer(
    overrides: [
      initialLocationProvider.overrideWithValue(path),
      authRepositoryProvider.overrideWithValue(auth),
      profileRepositoryProvider.overrideWithValue(profiles),
    ],
  );
  addTearDown(() async {
    container.dispose();
    await auth.changes.close();
  });
  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const MixTickApp()),
  );
  await tester.pumpAndSettle();
  expect(
    container.read(routerProvider).routeInformationProvider.value.uri.path,
    auth.current?.requiresPasswordChange == true ? '/access/reset' : path,
  );
  return container;
}

Future<void> tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pump();
}

void main() {
  WidgetController.hitTestWarningShouldBeFatal = true;
  test(
    'A02/A03 validación local rechaza email, espacios y contraseña débil',
    () {
      for (final email in [
        'a',
        '@example.test',
        'a@',
        'a b@example.test',
        'a@@example.test',
      ]) {
        expect(AuthValidation.validEmail(email), isFalse);
      }
      expect(AuthValidation.validEmail(' chef+mix@example.test '), isTrue);
      for (final password in ['', '1234567', '        ', 'x' * 129]) {
        expect(AuthValidation.validPassword(password), isFalse);
      }
      expect(AuthValidation.validPassword(' safe password '), isTrue);
    },
  );
  test(
    'P03 username sigue el contrato SQL, sin transformar acentos en alias',
    () {
      expect(ProfileValidation.normalizeUsername('  Chef_23  '), 'chef_23');
      for (final username in [
        'ab',
        'chef-name',
        'chef.name',
        'café',
        'x' * 31,
      ]) {
        expect(ProfileValidation.validUsername(username), isFalse);
      }
      expect(ProfileValidation.validDisplayName('  '), isFalse);
      expect(ProfileValidation.validDisplayName('🥑' * 60), isTrue);
      expect(ProfileValidation.validDisplayName('🥑' * 61), isFalse);
    },
  );
  test('Retorno PKCE exacto: rechaza host/path alternativos, tokens y parámetros duplicados', () {
    expect(
      AuthCallback.valid(
        Uri.parse('${AuthCallback.redirectUrl}?code=valid_code_12345'),
      ),
      isTrue,
    );
    for (final link in [
      'other://auth/callback?code=valid_code_12345',
      'es.sergiotech.mixtick://other/callback?code=valid_code_12345',
      'es.sergiotech.mixtick://auth/other?code=valid_code_12345',
      '${AuthCallback.redirectUrl}?code=valid_code_12345&code=other',
      '${AuthCallback.redirectUrl}?code=valid_code_12345&redirect_to=https://example.test',
      '${AuthCallback.redirectUrl}#access_token=test',
      '${AuthCallback.redirectUrl}?error=expired',
    ]) {
      expect(AuthCallback.valid(Uri.parse(link)), isFalse);
    }
  });
  test(
    'HTTP solo en desarrollo explícito y endpoint local, nunca host LAN',
    () {
      AppConfig local(String endpoint, {bool enabled = true}) => AppConfig(
        supabaseUrl: endpoint,
        publishableKey: 'sb_publishable_test',
        allowLocalBackend: enabled,
      );
      expect(local('http://127.0.0.1:54321').status, ConfigStatus.ready);
      expect(local('http://10.0.2.2:54321').status, ConfigStatus.ready);
      expect(
        local('http://127.0.0.1:54321', enabled: false).status,
        ConfigStatus.invalid,
      );
      expect(local('http://192.168.1.2:54321').status, ConfigStatus.invalid);
      expect(local('http://127.0.0.1:8000').status, ConfigStatus.invalid);
    },
  );
  test(
    'P06 bytes no permitidos y tamaño excesivo se rechazan antes de subir',
    () {
      expect(
        () => AvatarImage.extension(Uint8List.fromList([1, 2, 3])),
        throwsA(isA<ProfileFailure>()),
      );
      expect(
        () => AvatarImage.extension(Uint8List(AvatarImage.maximumBytes + 1)),
        throwsA(isA<ProfileFailure>()),
      );
    },
  );
  testWidgets('A02 email inválido no llega al repositorio (mock)', (
    tester,
  ) async {
    final auth = FakeAuthRepository();
    await mount(tester, auth);
    await tester.enterText(find.byKey(const ValueKey('email')), 'invalid');
    await tester.enterText(find.byKey(const ValueKey('password')), 'password');
    await tap(tester, find.byKey(const ValueKey('submit-auth')));
    expect(
      find.text('Introduce un correo electrónico válido.'),
      findsOneWidget,
    );
    expect(auth.signInCalls, 0);
  });
  testWidgets('A03 registro valida repetición y contraseña (mock)', (
    tester,
  ) async {
    final auth = FakeAuthRepository();
    await mount(tester, auth, path: '/access/register');
    await tester.enterText(
      find.byKey(const ValueKey('email')),
      'test@example.test',
    );
    await tester.enterText(find.byKey(const ValueKey('password')), 'short');
    await tester.enterText(
      find.byKey(const ValueKey('repeat-password')),
      'other',
    );
    await tap(tester, find.byKey(const ValueKey('submit-auth')));
    expect(find.text('Usa entre 8 y 128 caracteres.'), findsOneWidget);
    expect(find.text('Las contraseñas no coinciden.'), findsOneWidget);
    expect(auth.signUpCalls, 0);
  });
  testWidgets(
    'A05/I02 doble envío deshabilitado y cuatro pestañas después de login (mock)',
    (tester) async {
      final auth = FakeAuthRepository()..pending = Completer<void>();
      await mount(tester, auth);
      await tester.enterText(
        find.byKey(const ValueKey('email')),
        'test@example.test',
      );
      await tester.enterText(
        find.byKey(const ValueKey('password')),
        'password',
      );
      await tap(tester, find.byKey(const ValueKey('submit-auth')));
      final button = tester.widget<FilledButton>(
        find.byKey(const ValueKey('submit-auth')),
      );
      expect(button.onPressed, isNull);
      expect(auth.signInCalls, 1);
      auth.pending!.complete();
      await tester.pumpAndSettle();
      expect(find.byType(NavigationDestination), findsNWidgets(4));
    },
  );
  testWidgets('A06/I05 error de conectividad comprensible y reintento (mock)', (
    tester,
  ) async {
    final auth = FakeAuthRepository()
      ..failure = const AuthFailure(AuthFailureCode.network);
    await mount(tester, auth);
    await tester.enterText(
      find.byKey(const ValueKey('email')),
      'test@example.test',
    );
    await tester.enterText(find.byKey(const ValueKey('password')), 'password');
    await tap(tester, find.byKey(const ValueKey('submit-auth')));
    await tester.pumpAndSettle();
    expect(find.textContaining('No pudimos conectar'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const ValueKey('submit-auth')))
          .onPressed,
      isNotNull,
    );
    expect(find.byType(NavigationDestination), findsNothing);
  });
  testWidgets('A11 registro sin sesión lleva a confirmación genérica (mock)', (
    tester,
  ) async {
    final auth = FakeAuthRepository();
    await mount(tester, auth, path: '/access/register');
    await tester.enterText(
      find.byKey(const ValueKey('email')),
      'test@example.test',
    );
    await tester.enterText(
      find.byKey(const ValueKey('password')),
      'password-safe',
    );
    await tester.enterText(
      find.byKey(const ValueKey('repeat-password')),
      'password-safe',
    );
    await tap(tester, find.byKey(const ValueKey('submit-auth')));
    await tester.pumpAndSettle();
    expect(find.text('Revisa tu correo'), findsOneWidget);
    expect(
      find.textContaining('Si el correo puede registrarse'),
      findsOneWidget,
    );
    expect(find.byType(NavigationDestination), findsNothing);
  });
  testWidgets('A10 recuperar no revela si el correo existe (mock)', (
    tester,
  ) async {
    final auth = FakeAuthRepository();
    await mount(tester, auth, path: '/access/recovery');
    await tester.enterText(
      find.byKey(const ValueKey('email')),
      'test@example.test',
    );
    await tap(tester, find.byKey(const ValueKey('submit-auth')));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Si el correo corresponde a una cuenta'),
      findsOneWidget,
    );
    expect(auth.resetCalls, 1);
  });
  testWidgets('Recuperación activa protege pestañas hasta actualizar (mock)', (
    tester,
  ) async {
    final auth = FakeAuthRepository()
      ..current = const AuthSession(
        userId: 'test-a',
        requiresPasswordChange: true,
      );
    final container = await mount(tester, auth, path: '/shopping');
    expect(
      container.read(routerProvider).routeInformationProvider.value.uri.path,
      '/access/reset',
    );
    expect(find.byType(NavigationDestination), findsNothing);
    expect(find.byKey(const ValueKey('password')), findsOneWidget);
  });
  testWidgets('P01/P02 perfil realista y validación de username (mock)', (
    tester,
  ) async {
    final auth = FakeAuthRepository()
      ..current = const AuthSession(userId: 'test-a');
    final profiles = FakeProfileRepository(auth);
    await mount(tester, auth, path: '/profile/edit', profiles: profiles);
    await tester.enterText(find.byKey(const ValueKey('display-name')), 'Ana');
    await tester.enterText(find.byKey(const ValueKey('username')), 'café');
    await tap(tester, find.byKey(const ValueKey('save-profile')));
    expect(profiles.writes, 0);
    expect(find.textContaining('Usa de 3 a 30 letras'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('username')), ' Chef_A ');
    await tap(tester, find.byKey(const ValueKey('save-profile')));
    await tester.pumpAndSettle();
    expect(profiles.profiles['test-a']!.username, 'chef_a');
    expect(find.text('@chef_a'), findsOneWidget);
  });
  testWidgets(
    'P03 conflicto de username muestra error sin perder formulario (mock)',
    (tester) async {
      final auth = FakeAuthRepository()
        ..current = const AuthSession(userId: 'test-a');
      final profiles = FakeProfileRepository(auth)
        ..failure = const ProfileFailure(ProfileFailureCode.usernameTaken);
      await mount(tester, auth, path: '/profile/edit', profiles: profiles);
      await tester.enterText(find.byKey(const ValueKey('display-name')), 'Ana');
      await tester.enterText(find.byKey(const ValueKey('username')), 'chef_a');
      await tap(tester, find.byKey(const ValueKey('save-profile')));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Ese nombre de usuario no está disponible'),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('save-profile')), findsOneWidget);
    },
  );
  testWidgets('P05 público muestra solo nombre, username y foto (mock)', (
    tester,
  ) async {
    final auth = FakeAuthRepository()
      ..current = const AuthSession(userId: 'test-a');
    final profiles = FakeProfileRepository(auth)
      ..profiles['test-a'] = const UserProfile(
        userId: 'test-a',
        version: 7,
        username: 'chef_a',
        displayName: 'Ana',
      );
    await mount(tester, auth, path: '/people/chef_a', profiles: profiles);
    expect(find.text('Ana'), findsOneWidget);
    expect(find.text('@chef_a'), findsOneWidget);
    expect(find.text('test-a@example.test'), findsNothing);
    expect(find.text('test-a'), findsNothing);
    expect(find.text('7'), findsNothing);
  });
  testWidgets(
    'I03 logout devuelve al acceso y limpia datos privados de UI (mock)',
    (tester) async {
      final auth = FakeAuthRepository()
        ..current = const AuthSession(userId: 'test-a');
      await mount(tester, auth, path: '/profile');
      await tap(tester, find.text('Cerrar sesión'));
      await tester.pumpAndSettle();
      expect(find.text('Tu cocina, en un solo lugar'), findsOneWidget);
      expect(find.text('test-a@example.test'), findsNothing);
    },
  );
  testWidgets(
    'I04 cambiar cuenta descarta el borrador privado del editor (mock)',
    (tester) async {
      final auth = FakeAuthRepository()
        ..current = const AuthSession(userId: 'test-a');
      final profiles = FakeProfileRepository(auth);
      profiles.profiles.addAll({
        'test-a': const UserProfile(
          userId: 'test-a',
          version: 1,
          username: 'chef_a',
          displayName: 'Ana',
        ),
        'test-b': const UserProfile(
          userId: 'test-b',
          version: 1,
          username: 'chef_b',
          displayName: 'Beto',
        ),
      });
      await mount(tester, auth, path: '/profile/edit', profiles: profiles);
      await tester.enterText(
        find.byKey(const ValueKey('display-name')),
        'Borrador privado A',
      );
      auth.setSession(const AuthSession(userId: 'test-b'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextFormField>(find.byKey(const ValueKey('display-name')))
            .controller!
            .text,
        'Beto',
      );
      expect(find.text('Borrador privado A'), findsNothing);
    },
  );
  testWidgets(
    'Un enlace de retorno espera la operación en curso, sin perderse (mock)',
    (tester) async {
      final auth = FakeAuthRepository();
      final container = await mount(tester, auth);
      final blocker = Completer<void>();
      final controller = container.read(authControllerProvider.notifier);
      final pending = controller.execute((_) => blocker.future);
      final callback = controller.processCallback(
        Uri.parse('${AuthCallback.redirectUrl}?code=valid_code_12345'),
      );
      await tester.pump();
      expect(container.read(authControllerProvider).busy, isTrue);
      blocker.complete();
      expect(await pending, isTrue);
      expect(await callback, isFalse);
      expect(
        container.read(authControllerProvider).failure,
        AuthFailureCode.invalidLink,
      );
    },
  );
  for (final brightness in Brightness.values) {
    testWidgets('Formularios a 200 % y 320 px, tema $brightness (mock)', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      tester.platformDispatcher.platformBrightnessTestValue = brightness;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      final auth = FakeAuthRepository();
      final container = await mount(tester, auth);
      for (final path in [
        '/access/login',
        '/access/register',
        '/access/recovery',
        '/access/confirm',
        '/access/reset',
      ]) {
        container.read(routerProvider).go(path);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
    });
  }
}
