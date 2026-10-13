import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mixtick/app/app.dart';
import 'package:mixtick/app/router.dart';
import 'package:mixtick/features/auth/domain/auth_session.dart';
import 'package:mixtick/features/auth/presentation/access_page.dart';
import 'package:mixtick/features/auth/presentation/auth_providers.dart';
import 'package:mixtick/features/auth/presentation/session_page.dart';
import 'package:mixtick/features/community/presentation/community_page.dart';
import 'package:mixtick/features/cook_today/presentation/cook_today_page.dart';
import 'package:mixtick/features/profile/presentation/profile_page.dart';
import 'package:mixtick/features/recipes/presentation/recipes_page.dart';
import 'package:mixtick/features/shopping/presentation/shopping_page.dart';
import 'package:mixtick/shared/models/app_module.dart';

// Controlled identities exist exclusively in tests, never in the mobile app.
const testSession = AuthSession(userId: 'test-user-a');
const previewKey = ValueKey('foundation-preview');

Future<void> capturePreview(WidgetTester tester, String name) async {
  if (!const bool.fromEnvironment('CAPTURE_FOUNDATION_PREVIEWS')) return;
  await tester.runAsync(() async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(previewKey),
    );
    final image = await boundary.toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('docs/reports/previews/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

Future<ProviderContainer> mount(
  WidgetTester tester, {
  String location = '/community',
  Stream<AuthSession?>? sessions,
}) async {
  final container = ProviderContainer(
    overrides: [
      initialLocationProvider.overrideWithValue(location),
      authSessionProvider.overrideWith(
        (ref) => sessions ?? Stream.value(testSession),
      ),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    RepaintBoundary(
      key: previewKey,
      child: UncontrolledProviderScope(
        container: container,
        child: const MixTickApp(),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  return container;
}

void main() {
  WidgetController.hitTestWarningShouldBeFatal = true;
  setUpAll(() async {
    if (!const bool.fromEnvironment('CAPTURE_FOUNDATION_PREVIEWS')) return;
    final packageConfig = jsonDecode(
      File('.dart_tool/package_config.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final flutterPackage = (packageConfig['packages'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .firstWhere((package) => package['name'] == 'flutter');
    final flutterRoot = Directory.fromUri(
      Uri.parse(flutterPackage['rootUri'] as String),
    ).path;
    final loader = FontLoader('Roboto');
    for (final weight in ['regular', 'medium', 'bold']) {
      final bytes = await File(
        '$flutterRoot/../../bin/cache/artifacts/material_fonts/roboto-$weight.ttf',
      ).readAsBytes();
      loader.addFont(Future.value(ByteData.sublistView(bytes)));
    }
    await loader.load();
    final icons = FontLoader('MaterialIcons');
    final iconBytes = await File(
      '$flutterRoot/../../bin/cache/artifacts/material_fonts/materialicons-regular.otf',
    ).readAsBytes();
    icons.addFont(Future.value(ByteData.sublistView(iconBytes)));
    await icons.load();
  });
  testWidgets('Exactamente cuatro pestañas navegan y perfil no añade otra', (
    tester,
  ) async {
    await mount(tester);
    expect(find.byType(NavigationDestination), findsNWidgets(4));
    expect(find.byType(CommunityPage), findsOneWidget);
    for (final entry in <AppModule, Type>{
      AppModule.recipes: RecipesPage,
      AppModule.cookToday: CookTodayPage,
      AppModule.shopping: ShoppingPage,
      AppModule.community: CommunityPage,
    }.entries) {
      await tester.tap(find.byKey(ValueKey(entry.key)));
      await tester.pumpAndSettle();
      expect(find.byType(entry.value), findsOneWidget);
    }
    await tester.tap(find.byTooltip('Mi perfil'));
    await tester.pumpAndSettle();
    expect(find.byType(ProfilePage), findsOneWidget);
    expect(find.byType(NavigationDestination), findsNothing);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.byType(NavigationDestination), findsNWidgets(4));
  });

  for (final path in [
    ...AppModule.values.map((module) => module.path),
    '/profile',
  ]) {
    testWidgets('Sin sesión protege el acceso directo a $path', (tester) async {
      final container = await mount(
        tester,
        location: path,
        sessions: Stream.value(null),
      );
      expect(
        container.read(routerProvider).routeInformationProvider.value.uri.path,
        '/access',
      );
      expect(find.byType(AccessPage), findsOneWidget);
      expect(find.byType(NavigationDestination), findsNothing);
    });
  }

  testWidgets('Esperar sesión no muestra contenido protegido', (tester) async {
    final controller = StreamController<AuthSession?>();
    addTearDown(controller.close);
    await mount(tester, sessions: controller.stream);
    expect(find.byType(SessionPage), findsOneWidget);
    expect(find.byType(NavigationDestination), findsNothing);
    controller.add(null);
    await tester.pumpAndSettle();
    expect(find.byType(AccessPage), findsOneWidget);
  });

  testWidgets('Un error de sesión impide entrar y tiene mensaje comprensible', (
    tester,
  ) async {
    await mount(
      tester,
      sessions: Stream.error(StateError('controlled test failure')),
    );
    expect(find.byType(AccessPage), findsOneWidget);
    await tester.ensureVisible(find.text('Consultar estado del acceso'));
    await tester.tap(find.text('Consultar estado del acceso'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('No pudimos comprobar tu sesión'),
      findsOneWidget,
    );
    expect(find.byType(NavigationDestination), findsNothing);
  });

  testWidgets('Cambios de sesión abren el shell y vuelven a protegerlo', (
    tester,
  ) async {
    final controller = StreamController<AuthSession?>();
    addTearDown(controller.close);
    final container = await mount(tester, sessions: controller.stream);
    controller.add(testSession);
    await tester.pumpAndSettle();
    container.read(routerProvider).go('/shopping');
    await tester.pumpAndSettle();
    expect(find.byType(ShoppingPage), findsOneWidget);
    controller.add(null);
    await tester.pumpAndSettle();
    expect(find.byType(AccessPage), findsOneWidget);
    expect(find.byType(ShoppingPage), findsNothing);
  });

  testWidgets('Sin backend informa del acceso pendiente y permite volver', (
    tester,
  ) async {
    await mount(tester, sessions: Stream.value(null));
    await tester.ensureVisible(find.text('Consultar estado del acceso'));
    await tester.tap(find.text('Consultar estado del acceso'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('El servicio de acceso todavía no está disponible'),
      findsOneWidget,
    );
    await tester.tap(find.text('Volver al acceso'));
    await tester.pumpAndSettle();
    expect(find.byType(AccessPage), findsOneWidget);
  });

  for (final brightness in Brightness.values) {
    testWidgets('Español, tema $brightness y texto grande en móvil estrecho', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.platformBrightnessTestValue = brightness;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await mount(tester, sessions: Stream.value(null));
      expect(find.text('Tu cocina, en un solo lugar'), findsOneWidget);
      final context = tester.element(find.byType(AccessPage));
      expect(Localizations.localeOf(context).languageCode, 'es');
      expect(Localizations.localeOf(context).countryCode, 'ES');
      expect(Theme.of(context).brightness, brightness);
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Consultar estado del acceso'));
      expect(
        find.text('Consultar estado del acceso').hitTestable(),
        findsOneWidget,
      );
    });

    testWidgets('Cuatro pestañas con texto grande y tema $brightness', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.platformBrightnessTestValue = brightness;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final container = await mount(tester);
      for (final module in AppModule.values) {
        container.read(routerProvider).go(module.path);
        await tester.pumpAndSettle();
        expect(find.byType(NavigationDestination), findsNWidgets(4));
        expect(find.byKey(ValueKey(module)).hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('Render móvil de acceso y pestañas en tema $brightness', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.platformBrightnessTestValue = brightness;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      final controller = StreamController<AuthSession?>();
      addTearDown(controller.close);
      final container = await mount(tester, sessions: controller.stream);
      controller.add(null);
      await tester.pumpAndSettle();
      await capturePreview(tester, 'access-${brightness.name}');
      controller.add(testSession);
      await tester.pumpAndSettle();
      for (final module in AppModule.values) {
        container.read(routerProvider).go(module.path);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await capturePreview(tester, '${module.name}-${brightness.name}');
      }
    });
  }
}
