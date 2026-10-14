// UI/state mocks only. Real server deletion is verified independently.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mixtick/app/app.dart';
import 'package:mixtick/app/router.dart';
import 'package:mixtick/features/auth/domain/auth_session.dart';
import 'package:mixtick/features/auth/presentation/auth_providers.dart';
import 'package:mixtick/features/profile/domain/account_deletion_repository.dart';
import 'package:mixtick/features/profile/presentation/account_deletion_page.dart';

import '../support/fake_repositories.dart';

class DeletionMock implements AccountDeletionRepository {
  final requests = <String>[];
  Completer<void>? pending;
  AccountDeletionFailure? failure;
  @override
  Future<void> request(String password, String requestId) async {
    requests.add(requestId);
    await pending?.future;
    if (failure != null) throw failure!;
  }
}

Future<void> mount(
  WidgetTester tester,
  FakeAuthRepository auth,
  DeletionMock repo,
) async {
  final container = ProviderContainer(
    overrides: [
      authRepositoryProvider.overrideWithValue(auth),
      initialLocationProvider.overrideWithValue('/account/delete'),
      accountDeletionRepositoryProvider.overrideWithValue(repo),
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
}

Future<void> confirm(WidgetTester tester) async {
  final agree = find.byKey(const ValueKey('delete-account-agree'));
  await tester.scrollUntilVisible(
    agree,
    160,
    scrollable: find.byType(Scrollable).first,
  );
  await Scrollable.ensureVisible(tester.element(agree), alignment: 0.5);
  await tester.pump();
  await tester.tap(agree);
  await tester.pump();
  await tester.scrollUntilVisible(
    find.byKey(const ValueKey('delete-account-password')),
    160,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.enterText(
    find.byKey(const ValueKey('delete-account-password')),
    'controlled-password',
  );
  await tester.scrollUntilVisible(
    find.byKey(const ValueKey('delete-account-confirm')),
    160,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.enterText(
    find.byKey(const ValueKey('delete-account-confirm')),
    'ELIMINAR',
  );
  await tester.pump();
}

Future<void> submit(WidgetTester tester) async {
  final button = find.byKey(const ValueKey('delete-account-submit'));
  await tester.scrollUntilVisible(
    button,
    160,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pump();
}

void main() {
  WidgetController.hitTestWarningShouldBeFatal = true;
  testWidgets(
    'D01 explicit consequences/list confirmation/password required (UI mock)',
    (tester) async {
      final auth = FakeAuthRepository()
        ..current = const AuthSession(userId: 'test-a');
      final repo = DeletionMock();
      await mount(tester, auth, repo);
      expect(find.textContaining('irreversible'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const ValueKey('delete-account-submit')),
            )
            .onPressed,
        isNull,
      );
      await confirm(tester);
      await submit(tester);
      await tester.pumpAndSettle();
      expect(repo.requests, hasLength(1));
      expect(auth.current, isNull);
      expect(find.textContaining('Eliminación aceptada'), findsOneWidget);
    },
  );
  testWidgets(
    'D10 retry after ambiguous failure preserves request and credentials (UI mock)',
    (tester) async {
      final auth = FakeAuthRepository()
        ..current = const AuthSession(userId: 'test-a');
      final repo = DeletionMock()
        ..failure = const AccountDeletionFailure(
          AccountDeletionFailureCode.network,
        );
      await mount(tester, auth, repo);
      await confirm(tester);
      await submit(tester);
      await tester.pumpAndSettle();
      expect(find.textContaining('podría haberse aceptado'), findsOneWidget);
      repo.failure = null;
      await submit(tester);
      await tester.pumpAndSettle();
      expect(repo.requests, hasLength(2));
      expect(repo.requests[0], repo.requests[1]);
      expect(auth.current, isNull);
    },
  );
  testWidgets(
    'D12 late acceptance from A must not sign out B or retain fields (UI mock)',
    (tester) async {
      final auth = FakeAuthRepository()
        ..current = const AuthSession(userId: 'test-a');
      final repo = DeletionMock()..pending = Completer<void>();
      await mount(tester, auth, repo);
      await confirm(tester);
      await submit(tester);
      auth.setSession(const AuthSession(userId: 'test-b'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(
              find.byKey(const ValueKey('delete-account-password')),
            )
            .controller!
            .text,
        isEmpty,
      );
      repo.pending!.complete();
      await tester.pumpAndSettle();
      expect(auth.current?.userId, 'test-b');
    },
  );
  for (final brightness in Brightness.values) {
    testWidgets('Account deletion 320x640 text200 $brightness (UI mock)', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      tester.platformDispatcher.platformBrightnessTestValue = brightness;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.platformDispatcher.clearTextScaleFactorTestValue();
        tester.platformDispatcher.clearPlatformBrightnessTestValue();
      });
      final auth = FakeAuthRepository()
        ..current = const AuthSession(userId: 'test-a');
      await mount(tester, auth, DeletionMock());
      final semantics = tester.ensureSemantics();
      try {
        await confirm(tester);
        await tester.scrollUntilVisible(
          find.byKey(const ValueKey('delete-account-submit')),
          160,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.ensureVisible(
          find.byKey(const ValueKey('delete-account-submit')),
        );
        // Assess the enabled colors after Material's disabled->enabled animation.
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await expectLater(tester, meetsGuideline(textContrastGuideline));
      } finally {
        semantics.dispose();
      }
    });
  }
}
