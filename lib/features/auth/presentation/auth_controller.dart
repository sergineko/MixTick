import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'dart:async';

import '../domain/auth_repository.dart';
import '../domain/auth_failure.dart';
import 'auth_providers.dart';

class AuthActionState {
  const AuthActionState({this.busy = false, this.failure});
  final bool busy;
  final AuthFailureCode? failure;
}

final authControllerProvider =
    NotifierProvider<AuthController, AuthActionState>(AuthController.new);

class AuthController extends Notifier<AuthActionState> {
  String? confirmationEmail;
  Future<void>? _pending;
  @override
  AuthActionState build() => const AuthActionState();
  Future<bool> execute(Future<void> Function(AuthRepository) action) async {
    if (state.busy) return false;
    final repository = ref.read(authRepositoryProvider);
    if (repository == null) {
      state = const AuthActionState(failure: AuthFailureCode.unavailable);
      return false;
    }
    state = const AuthActionState(busy: true);
    final completion = Completer<void>();
    _pending = completion.future;
    try {
      await action(repository);
      if (ref.mounted) state = const AuthActionState();
      return true;
    } on AuthFailure catch (error) {
      if (ref.mounted) state = AuthActionState(failure: error.code);
    } catch (_) {
      if (ref.mounted) {
        state = const AuthActionState(failure: AuthFailureCode.unexpected);
      }
    } finally {
      completion.complete();
      _pending = null;
    }
    return false;
  }

  Future<bool> processCallback(Uri uri) async {
    while (_pending != null) {
      await _pending;
    }
    if (!ref.mounted) return false;
    return execute((repo) => repo.handleCallback(uri));
  }

  void clearError() {
    if (!state.busy) state = const AuthActionState();
  }
}
