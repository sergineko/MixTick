// Test doubles only: these prove UI/state behavior, never Auth or RLS permissions.
import 'dart:async';
import 'dart:typed_data';

import 'package:mixtick/features/auth/domain/auth_repository.dart';
import 'package:mixtick/features/auth/domain/auth_session.dart';
import 'package:mixtick/features/auth/domain/auth_failure.dart';
import 'package:mixtick/features/profile/domain/profile_repository.dart';
import 'package:mixtick/features/profile/domain/user_profile.dart';

class FakeAuthRepository implements AuthRepository {
  AuthSession? current;
  final changes = StreamController<AuthSession?>.broadcast();
  int signInCalls = 0;
  int signUpCalls = 0;
  int resetCalls = 0;
  Completer<void>? pending;
  AuthFailure? failure;
  bool confirmation = true;
  void setSession(AuthSession? session) {
    current = session;
    changes.add(session);
  }

  @override
  Stream<AuthSession?> watchSession() async* {
    yield current;
    yield* changes.stream;
  }

  @override
  String? get currentEmail =>
      current == null ? null : '${current!.userId}@example.test';
  @override
  Future<void> signIn(String email, String password) async {
    signInCalls++;
    await pending?.future;
    if (failure != null) throw failure!;
    setSession(const AuthSession(userId: 'test-a'));
  }

  @override
  Future<bool> signUp(String email, String password) async {
    signUpCalls++;
    if (failure != null) throw failure!;
    return confirmation;
  }

  @override
  Future<void> signOut() async => setSession(null);
  @override
  Future<void> requestPasswordReset(String email) async {
    resetCalls++;
    if (failure != null) throw failure!;
  }

  @override
  Future<void> resendConfirmation(String email) async {}
  @override
  Future<void> updatePassword(String password) async =>
      setSession(AuthSession(userId: current!.userId));
  @override
  Future<void> validateSession() async {}
  @override
  Future<void> handleCallback(Uri uri) async {
    throw const AuthFailure(AuthFailureCode.invalidLink);
  }
}

class FakeProfileRepository implements ProfileRepository {
  FakeProfileRepository(this.auth);
  final FakeAuthRepository auth;
  final profiles = <String, UserProfile>{};
  ProfileFailure? failure;
  int writes = 0;
  @override
  Future<UserProfile?> loadOwn() async => profiles[auth.current?.userId];
  @override
  Future<PublicProfile?> loadPublic(String username) async =>
      profiles.values.where((p) => p.username == username).firstOrNull;
  @override
  Future<UserProfile> save({
    required String username,
    required String displayName,
    UserProfile? previous,
    String? avatarPath,
  }) async {
    writes++;
    if (failure != null) throw failure!;
    final result = UserProfile(
      userId: auth.current!.userId,
      version: (previous?.version ?? 0) + 1,
      username: ProfileValidation.normalizeUsername(username),
      displayName: displayName.trim(),
      avatarPath: avatarPath,
    );
    profiles[result.userId] = result;
    return result;
  }

  @override
  Future<Uint8List> downloadAvatar(String path) async =>
      throw const ProfileFailure(ProfileFailureCode.invalidPhoto);
  @override
  Future<void> removeAvatar(String path) async {}
  @override
  Future<String> uploadAvatar(Uint8List bytes) async =>
      '${auth.current!.userId}/test.png';
}
