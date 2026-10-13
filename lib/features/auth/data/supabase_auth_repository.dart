import 'dart:async';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/auth_repository.dart';
import '../domain/auth_session.dart';
import '../domain/auth_failure.dart';
import '../domain/auth_validation.dart';

class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(
    this._client, {
    this._stateStorage,
    this.localStorage,
  }) {
    _subscription = _client.auth.onAuthStateChange.listen(
      (event) {
        _eventQueue = _eventQueue.then((_) => _onEvent(event)).catchError((
          Object _,
        ) {
          if (!_changes.isClosed) {
            _changes.addError(const AuthFailure(AuthFailureCode.unexpected));
          }
        });
      },
      onError: (Object error) {
        if (!_changes.isClosed) _changes.addError(_failure(error));
      },
    );
  }
  final SupabaseClient _client;
  final GotrueAsyncStorage? _stateStorage;
  final LocalStorage? localStorage;
  late final StreamSubscription<AuthState> _subscription;
  final _changes = StreamController<AuthSession?>.broadcast();
  Future<void> _eventQueue = Future.value();
  Future<void> _operations = Future.value();
  bool _recovery = false;
  static const _recoveryKey = 'mixtick-recovery-mode';
  AuthSession? get _identity {
    final session = _client.auth.currentSession;
    return session == null || session.isExpired
        ? null
        : AuthSession(
            userId: session.user.id,
            requiresPasswordChange: _recovery,
          );
  }

  Future<void> _onEvent(AuthState event) async {
    if (event.session?.accessToken !=
        _client.auth.currentSession?.accessToken) {
      return;
    }
    if (event.event == AuthChangeEvent.passwordRecovery) {
      _recovery = true;
      await _stateStorage?.setItem(
        key: _recoveryKey,
        value: event.session!.user.id,
      );
    } else if (event.event == AuthChangeEvent.signedOut) {
      _recovery = false;
      await _stateStorage?.removeItem(key: _recoveryKey);
    }
    if (!_changes.isClosed &&
        event.session?.accessToken ==
            _client.auth.currentSession?.accessToken) {
      _changes.add(_identity);
    }
  }

  @override
  String? get currentEmail => _client.auth.currentUser?.email;
  @override
  Stream<AuthSession?> watchSession() async* {
    try {
      await _run(() async {
        final userId = _client.auth.currentUser?.id;
        _recovery =
            userId != null &&
            await _stateStorage?.getItem(key: _recoveryKey) == userId;
      });
      await validateSession();
      yield _identity;
    } catch (error) {
      // Forward an initial failure without closing the session stream forever.
      // A later real sign-in or refresh can recover it after connectivity returns.
      yield* Stream<AuthSession?>.error(error);
    }
    yield* _changes.stream;
  }

  Future<T> _run<T>(Future<T> Function() action) {
    final completion = Completer<T>();
    _operations = _operations.then((_) async {
      try {
        completion.complete(await action());
      } catch (error, stack) {
        completion.completeError(_failure(error), stack);
      }
    });
    return completion.future;
  }

  static AuthFailure _failure(Object error) {
    if (error is AuthFailure) return error;
    if (error is SocketException ||
        error is TimeoutException ||
        error is AuthRetryableFetchException) {
      return const AuthFailure(AuthFailureCode.network);
    }
    if (error is AuthException) {
      return AuthFailure(switch (error.code) {
        'invalid_credentials' => AuthFailureCode.credentials,
        'email_not_confirmed' => AuthFailureCode.confirmationRequired,
        'weak_password' => AuthFailureCode.weakPassword,
        'over_request_rate_limit' ||
        'over_email_send_rate_limit' => AuthFailureCode.rateLimited,
        'session_not_found' ||
        'refresh_token_not_found' ||
        'refresh_token_already_used' => AuthFailureCode.sessionExpired,
        'otp_expired' ||
        'flow_state_not_found' ||
        'bad_code_verifier' => AuthFailureCode.invalidLink,
        _ =>
          error.statusCode == '429'
              ? AuthFailureCode.rateLimited
              : AuthFailureCode.unexpected,
      });
    }
    return const AuthFailure(AuthFailureCode.unexpected);
  }

  @override
  Future<void> validateSession() async {
    if (_client.auth.currentSession == null) return;
    try {
      await _run(() async {
        await _client.auth.refreshSession();
        final user = await _client.auth.getUser();
        if (user.user?.id != _client.auth.currentUser?.id) {
          throw const AuthFailure(AuthFailureCode.sessionExpired);
        }
      });
    } on AuthFailure catch (error) {
      if (error.code == AuthFailureCode.sessionExpired ||
          error.code == AuthFailureCode.credentials) {
        try {
          await _client.auth.signOut();
        } catch (_) {
          /* SDK clears local session first. */
        }
        return;
      }
      rethrow;
    }
  }

  @override
  Future<bool> signUp(String email, String password) => _run(() async {
    try {
      final response = await _client.auth.signUp(
        email: email.trim(),
        password: password,
        emailRedirectTo: AuthCallback.redirectUrl,
      );
      return response.session == null;
    } on AuthException catch (error) {
      if (error.code == 'user_already_exists' || error.code == 'email_exists') {
        return true;
      }
      rethrow;
    }
  });
  @override
  Future<void> signIn(String email, String password) => _run(() async {
    await _client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
    _recovery = false;
    await _stateStorage?.removeItem(key: _recoveryKey);
  });
  @override
  Future<void> signOut() => _run(() async {
    try {
      await _client.auth.signOut();
    } finally {
      await _eventQueue;
      await localStorage?.removePersistedSession();
    }
  });
  @override
  Future<void> requestPasswordReset(String email) => _run(
    () => _client.auth.resetPasswordForEmail(
      email.trim(),
      redirectTo: AuthCallback.redirectUrl,
    ),
  );
  @override
  Future<void> resendConfirmation(String email) => _run(() async {
    await _client.auth.resend(
      type: OtpType.signup,
      email: email.trim(),
      emailRedirectTo: AuthCallback.redirectUrl,
    );
  });
  @override
  Future<void> updatePassword(String password) => _run(() async {
    if (_identity == null) {
      throw const AuthFailure(AuthFailureCode.sessionExpired);
    }
    await _client.auth.updateUser(UserAttributes(password: password));
    await _eventQueue;
    _recovery = false;
    await _stateStorage?.removeItem(key: _recoveryKey);
    if (!_changes.isClosed) _changes.add(_identity);
  });
  @override
  Future<void> handleCallback(Uri uri) => _run(() async {
    if (!AuthCallback.valid(uri)) {
      throw const AuthFailure(AuthFailureCode.invalidLink);
    }
    try {
      await _client.auth.exchangeCodeForSession(uri.queryParameters['code']!);
    } catch (error) {
      final failure = _failure(error);
      if (failure.code == AuthFailureCode.network ||
          failure.code == AuthFailureCode.rateLimited) {
        rethrow;
      }
      throw const AuthFailure(AuthFailureCode.invalidLink);
    }
    await _eventQueue;
  });
  Future<void> dispose() async {
    await _subscription.cancel();
    await _eventQueue;
    await _changes.close();
  }
}
