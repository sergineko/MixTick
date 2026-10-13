import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mixtick/app/app.dart';
import 'package:mixtick/core/config/app_config.dart';
import 'package:mixtick/core/network/supabase_bootstrap.dart';

Future<void> until(
  WidgetTester tester,
  bool Function() condition, {
  int seconds = 30,
}) async {
  final limit = DateTime.now().add(Duration(seconds: seconds));
  while (!condition() && DateTime.now().isBefore(limit)) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(
    condition(),
    isTrue,
    reason: 'Native operation did not reach expected state',
  );
}

Future<ProviderContainer> mountNative(
  WidgetTester tester,
  AppConfig config,
) async {
  if (!config.allowLocalBackend ||
      config.supabaseUrl != 'http://10.0.2.2:54321') {
    throw StateError(
      'Native tests accept only the isolated Android emulator endpoint',
    );
  }
  final backend = await initializeSupabase(config);
  expect(backend.status, BackendStatus.initialized);
  final container = ProviderContainer(
    overrides: [
      appConfigProvider.overrideWithValue(config),
      backendProvider.overrideWithValue(backend),
    ],
  );
  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const MixTickApp()),
  );
  await until(
    tester,
    () =>
        find.text('Tu cocina, en un solo lugar').evaluate().isNotEmpty ||
        find.byType(NavigationDestination).evaluate().length == 4,
  );
  return container;
}

Future<void> nativeTap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pump(const Duration(milliseconds: 350));
}

Future<void> submitNative(
  WidgetTester tester,
  String email,
  String password, {
  bool repeat = false,
}) async {
  await tester.enterText(find.byKey(const ValueKey('email')), email);
  await tester.enterText(find.byKey(const ValueKey('password')), password);
  if (repeat) {
    await tester.enterText(
      find.byKey(const ValueKey('repeat-password')),
      password,
    );
  }
  await nativeTap(tester, find.byKey(const ValueKey('submit-auth')));
}
