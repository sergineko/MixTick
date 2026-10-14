import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mixtick/app/app.dart';
import 'package:mixtick/app/router.dart';
import 'package:mixtick/features/auth/domain/auth_session.dart';
import 'package:mixtick/features/auth/presentation/auth_providers.dart';
import 'package:mixtick/features/shopping/domain/shopping.dart';
import 'package:mixtick/features/shopping/presentation/shopping_providers.dart';
import 'package:mixtick/features/shopping/presentation/shopping_widgets.dart';
import 'package:mixtick/features/shopping/presentation/shopping_import_page.dart';
import 'package:mixtick/features/cook_today/domain/matching.dart';

import '../support/fake_shopping_repository.dart';

Future<ProviderContainer> mountShopping(
  WidgetTester tester,
  FakeShoppingRepository repo, {
  String path = '/shopping/list/list-a',
  Stream<AuthSession?>? sessions,
}) async {
  final container = ProviderContainer(
    overrides: [
      initialLocationProvider.overrideWithValue(path),
      authSessionProvider.overrideWith(
        (ref) => sessions ?? Stream.value(const AuthSession(userId: 'test-a')),
      ),
      shoppingRepositoryProvider.overrideWithValue(repo),
    ],
  );
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    container.dispose();
  });
  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const MixTickApp()),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pumpAndSettle();
  return container;
}

Future<void> tapShopping(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      finder,
      150,
      scrollable: find.byType(Scrollable).first,
    );
  }
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  WidgetController.hitTestWarningShouldBeFatal = true;
  testWidgets('L48 reload retries an initial failed read (mock)', (
    tester,
  ) async {
    final repo = FakeShoppingRepository()
      ..readFailure = ShoppingFailureCode.network;
    await mountShopping(tester, repo);
    expect(find.text('Jabón'), findsNothing);
    repo.readFailure = null;
    await tapShopping(tester, find.byTooltip('Recargar desde el servidor'));
    expect(find.text('Jabón'), findsOneWidget);
  });
  testWidgets('L18 denied editor closes and discards protected fields (mock)', (
    tester,
  ) async {
    final repo = FakeShoppingRepository();
    await mountShopping(tester, repo);
    await tapShopping(tester, find.byKey(const ValueKey('shop-edit-item-a')));
    repo.forbidden = true;
    repo.editFailure = ShoppingFailureCode.forbidden;
    await tapShopping(tester, find.byKey(const ValueKey('shop-editor-save')));
    expect(find.byType(ShoppingEditor), findsNothing);
    expect(find.text('Jabón'), findsNothing);
  });
  testWidgets(
    'L04 own list deletion requires confirmation; cancelling preserves it (mock)',
    (tester) async {
      final repo = FakeShoppingRepository();
      await mountShopping(tester, repo);
      await tapShopping(tester, find.byKey(const ValueKey('shop-delete-list')));
      await tapShopping(
        tester,
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Cancelar'),
        ),
      );
      expect(repo.deleted, 0);
      await tapShopping(tester, find.byKey(const ValueKey('shop-delete-list')));
      await tapShopping(
        tester,
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(FilledButton),
        ),
      );
      expect(repo.deleted, 1);
    },
  );
  test(
    'L36 manual household names stay free; amount validation is precise',
    () {
      expect(
        const ShoppingDraft('Jabón', quantity: 0.125, unit: 'l').valid,
        isTrue,
      );
      expect(const ShoppingDraft('Jabón').json['ingredient_id'], isNull);
      for (final value in [
        0.0,
        -1.0,
        1.0001,
        double.infinity,
        double.nan,
        1000001.0,
      ]) {
        expect(ShoppingDraft('Producto', quantity: value).valid, isFalse);
      }
      expect(const ShoppingDraft(' ').valid, isFalse);
      expect(ShoppingDraft('x' * 81).valid, isFalse);
    },
  );
  test(
    'L32 version/line identity/optional check prevents stale matching import',
    () {
      const transfer = MissingIngredientsTransfer(
        recipeId: 'recipe-a',
        recipeVersion: 1,
        lines: [importLine],
      );
      expect(importPreview.accepts(transfer), isTrue);
      expect(
        importPreview.accepts(
          const MissingIngredientsTransfer(
            recipeId: 'recipe-a',
            recipeVersion: 2,
            lines: [importLine],
          ),
        ),
        isFalse,
      );
      expect(
        importPreview.accepts(
          const MissingIngredientsTransfer(
            recipeId: 'recipe-a',
            recipeVersion: 1,
            lines: [],
          ),
        ),
        isFalse,
      );
      expect(
        importPreview.accepts(
          const MissingIngredientsTransfer(
            recipeId: 'other',
            recipeVersion: 1,
            lines: [importLine],
          ),
        ),
        isFalse,
      );
    },
  );
  testWidgets(
    'L07 optimistic toggle is reconciled, pending/bought groups reflect server (mock)',
    (tester) async {
      final repo = FakeShoppingRepository()..holdToggle = Completer<void>();
      await mountShopping(tester, repo);
      await tester.tap(find.byKey(const ValueKey('shop-check-item-a')));
      await tester.pump();
      expect(find.byKey(const ValueKey('shop-check-item-a')), findsNothing);
      repo.holdToggle!.complete();
      await tester.pumpAndSettle();
      await tapShopping(tester, find.byKey(const ValueKey('shop-bought')));
      expect(
        tester
            .widget<Checkbox>(find.byKey(const ValueKey('shop-check-item-a')))
            .value,
        isTrue,
      );
    },
  );
  testWidgets(
    'L26 duplicate/out of order signals reread once and never duplicate rows (mock)',
    (tester) async {
      final repo = FakeShoppingRepository();
      await mountShopping(tester, repo);
      final before = repo.reads;
      repo.notify();
      repo.notify();
      repo.notify();
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pumpAndSettle();
      expect(repo.reads, before + 1);
      expect(find.text('Jabón'), findsOneWidget);
    },
  );
  testWidgets(
    'L48 quick draft survives network failure, exact retry keeps request UUID (mock)',
    (tester) async {
      final repo = FakeShoppingRepository()
        ..addFailure = ShoppingFailureCode.network;
      await mountShopping(tester, repo);
      await tester.enterText(
        find.byKey(const ValueKey('shop-quick-input')),
        'Papel',
      );
      await tapShopping(tester, find.byKey(const ValueKey('shop-quick-add')));
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('shop-quick-input')))
            .controller!
            .text,
        'Papel',
      );
      repo.addFailure = null;
      await tapShopping(tester, find.byKey(const ValueKey('shop-quick-add')));
      expect(repo.requests.toSet().length, 1);
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('shop-quick-input')))
            .controller!
            .text,
        isEmpty,
      );
    },
  );
  testWidgets(
    'L24 conflict preserves editor draft and blocks save until actual reload (mock)',
    (tester) async {
      final repo = FakeShoppingRepository()
        ..editFailure = ShoppingFailureCode.conflict;
      await mountShopping(tester, repo);
      await tapShopping(tester, find.byKey(const ValueKey('shop-edit-item-a')));
      await tester.enterText(
        find.byKey(const ValueKey('shop-editor-name')),
        'Mi borrador',
      );
      await tapShopping(tester, find.byKey(const ValueKey('shop-editor-save')));
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('shop-editor-name')))
            .controller!
            .text,
        'Mi borrador',
      );
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const ValueKey('shop-editor-save')),
            )
            .onPressed,
        isNull,
      );
      expect(find.text('Recargar desde el servidor'), findsWidgets);
    },
  );
  testWidgets('L18/29 permission revalidation clears protected rows (mock)', (
    tester,
  ) async {
    final repo = FakeShoppingRepository();
    await mountShopping(tester, repo);
    repo.forbidden = true;
    repo.notify();
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pumpAndSettle();
    expect(find.text('Jabón'), findsNothing);
    expect(find.byKey(const ValueKey('shop-quick-input')), findsNothing);
  });
  testWidgets('L27 session switch closes stream and drops draft/modal (mock)', (
    tester,
  ) async {
    final repo = FakeShoppingRepository(),
        sessions = StreamController<AuthSession?>.broadcast();
    addTearDown(sessions.close);
    final mounting = mountShopping(tester, repo, sessions: sessions.stream);
    sessions.add(const AuthSession(userId: 'test-a'));
    await mounting;
    await tapShopping(tester, find.byKey(const ValueKey('shop-edit-item-a')));
    await tester.enterText(
      find.byKey(const ValueKey('shop-editor-name')),
      'Privado A',
    );
    sessions.add(null);
    await tester.pumpAndSettle();
    expect(find.byType(ShoppingEditor), findsNothing);
    expect(repo.cancelled, repo.watches);
    expect(find.text('Privado A'), findsNothing);
  });
  testWidgets('L27 switching list routes disposes previous channel (mock)', (
    tester,
  ) async {
    final repo = FakeShoppingRepository();
    final container = await mountShopping(tester, repo);
    container.read(routerProvider).push('/shopping/list/list-b');
    await tester.pumpAndSettle();
    expect(repo.watches - repo.cancelled, 1);
  });
  for (final dark in [false, true]) {
    testWidgets(
      'L41/48 shopping accessible 320px 200% ${dark ? 'dark' : 'light'} (mock)',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        tester.platformDispatcher.platformBrightnessTestValue = dark
            ? Brightness.dark
            : Brightness.light;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
          tester.platformDispatcher.clearAllTestValues();
        });
        final repo = FakeShoppingRepository();
        await mountShopping(tester, repo, path: '/shopping');
        expect(find.byType(NavigationDestination), findsNWidgets(4));
        expect(tester.takeException(), isNull);
        await tapShopping(
          tester,
          find.byKey(const ValueKey('shop-list-list-a')),
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'L32 stale matching preview offers recalculation and no import (mock)',
    (tester) async {
      final repo = FakeShoppingRepository()
        ..importData = const ShoppingImportPreview(
          recipeId: 'recipe-a',
          version: 2,
          title: 'Nueva receta',
          servings: 2.5,
          lines: [importLine],
        );
      final container = await mountShopping(tester, repo, path: '/shopping');
      container
          .read(routerProvider)
          .push(
            '/shopping/import/recipe-a',
            extra: const MissingIngredientsTransfer(
              recipeId: 'recipe-a',
              recipeVersion: 1,
              lines: [importLine],
            ),
          );
      await tester.pumpAndSettle();
      expect(find.byType(ShoppingImportPage), findsOneWidget);
      expect(find.byKey(const ValueKey('shop-recalculate')), findsOneWidget);
      expect(find.byKey(const ValueKey('shop-import-confirm')), findsNothing);
      expect(repo.imports, 0);
    },
  );
}
