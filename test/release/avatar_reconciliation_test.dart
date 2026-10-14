import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mixtick/features/auth/domain/auth_session.dart';
import 'package:mixtick/features/auth/presentation/auth_providers.dart';
import 'package:mixtick/features/profile/domain/user_profile.dart';
import 'package:mixtick/features/profile/presentation/profile_providers.dart';

import '../support/fake_repositories.dart';

class LostAvatarResponse extends FakeProfileRepository {
  LostAvatarResponse(super.auth);
  final removed = <String>[];
  @override
  Future<UserProfile> save({
    required String username,
    required String displayName,
    UserProfile? previous,
    String? avatarPath,
  }) async {
    await super.save(
      username: username,
      displayName: displayName,
      previous: previous,
      avatarPath: avatarPath,
    );
    throw const ProfileFailure(ProfileFailureCode.network);
  }

  @override
  Future<void> removeAvatar(String path) async => removed.add(path);
}

void main() {
  test('Ambiguous avatar commit must not delete the newly active image (controller mock)', () async {
    final auth = FakeAuthRepository()
      ..current = const AuthSession(userId: 'test-a');
    final repo = LostAvatarResponse(auth);
    const previous = UserProfile(
      userId: 'test-a',
      version: 1,
      username: 'test_a',
      displayName: 'Test A',
    );
    repo.profiles['test-a'] = previous;
    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        profileRepositoryProvider.overrideWithValue(repo),
      ],
    );
    final subscription = container.listen(authSessionProvider, (_, _) {});
    await container.read(authSessionProvider.future);
    final success = await container
        .read(profileControllerProvider.notifier)
        .save(
          username: previous.username,
          displayName: previous.displayName,
          previous: previous,
          photo: Uint8List(1),
        );
    expect(success, false);
    expect(repo.profiles['test-a']!.avatarPath, 'test-a/test.png');
    expect(repo.removed, isEmpty);
    subscription.close();
    container.dispose();
    await auth.changes.close();
  });
}
