import 'dart:typed_data';

import 'package:flutter/painting.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/supabase_bootstrap.dart';
import '../../../core/network/content_revision.dart';
import '../../auth/presentation/auth_providers.dart';
import '../data/profile_photo_picker.dart';
import '../data/supabase_profile_repository.dart';
import '../domain/profile_repository.dart';
import '../domain/user_profile.dart';

final profileRepositoryProvider = Provider<ProfileRepository?>((ref) {
  final client = ref.watch(backendProvider).client;
  return client == null ? null : SupabaseProfileRepository(client);
});
final ownProfileProvider = FutureProvider.autoDispose<UserProfile?>((
  ref,
) async {
  final userId = ref.watch(
    authSessionProvider.select(
      (s) => s.hasError || s.isLoading ? null : s.value?.userId,
    ),
  );
  if (userId == null) {
    return null;
  }
  return ref.watch(profileRepositoryProvider)?.loadOwn();
});
final publicProfileProvider = FutureProvider.autoDispose
    .family<PublicProfile?, String>((ref, username) async {
      final userId = ref.watch(
        authSessionProvider.select(
          (s) => s.hasError || s.isLoading ? null : s.value?.userId,
        ),
      );
      if (userId == null) {
        return null;
      }
      return ref.watch(profileRepositoryProvider)?.loadPublic(username);
    });
final avatarProvider = FutureProvider.autoDispose.family<Uint8List, String>((
  ref,
  path,
) async {
  final userId = ref.watch(
    authSessionProvider.select(
      (s) => s.hasError || s.isLoading ? null : s.value?.userId,
    ),
  );
  final repo = ref.watch(profileRepositoryProvider);
  if (userId == null || repo == null) {
    throw const ProfileFailure(ProfileFailureCode.forbidden);
  }
  final bytes = await repo.downloadAvatar(path);
  if (ref.mounted) ref.onDispose(() => MemoryImage(bytes).evict());
  return bytes;
});
final photoPickerProvider = Provider<ProfilePhotoPicker>(
  (ref) => ProfilePhotoPicker(),
);

class ProfileActionState {
  const ProfileActionState({
    this.busy = false,
    this.failure,
    this.cleanupPending = false,
  });
  final bool busy;
  final ProfileFailureCode? failure;
  final bool cleanupPending;
}

final profileControllerProvider =
    NotifierProvider<ProfileController, ProfileActionState>(
      ProfileController.new,
    );

class ProfileController extends Notifier<ProfileActionState> {
  @override
  ProfileActionState build() {
    ref.watch(authSessionProvider.select((s) => s.value?.userId));
    return const ProfileActionState();
  }

  Future<bool> save({
    required String username,
    required String displayName,
    UserProfile? previous,
    Uint8List? photo,
    bool removePhoto = false,
  }) async {
    if (state.busy) return false;
    final repo = ref.read(profileRepositoryProvider);
    final actor = ref.read(authSessionProvider).value?.userId;
    if (repo == null || actor == null) return false;
    state = const ProfileActionState(busy: true);
    String? uploaded;
    try {
      if (photo != null) uploaded = await repo.uploadAvatar(photo);
      if (ref.read(authSessionProvider).value?.userId != actor) return false;
      await repo.save(
        username: username,
        displayName: displayName,
        previous: previous,
        avatarPath: uploaded ?? (removePhoto ? null : previous?.avatarPath),
      );
      var pending = false;
      if (previous?.avatarPath != null && (uploaded != null || removePhoto)) {
        try {
          await repo.removeAvatar(previous!.avatarPath!);
        } catch (_) {
          pending = true;
        }
      }
      if (ref.mounted && ref.read(authSessionProvider).value?.userId == actor) {
        ref.invalidate(ownProfileProvider);
        ref.read(contentRevisionProvider.notifier).changed();
        ref.invalidate(publicProfileProvider);
        ref.invalidate(avatarProvider);
        state = ProfileActionState(cleanupPending: pending);
      }
      return true;
    } catch (error) {
      if (uploaded != null) {
        try {
          await repo.removeAvatar(uploaded);
        } catch (_) {}
      }
      if (ref.mounted && ref.read(authSessionProvider).value?.userId == actor) {
        state = ProfileActionState(
          failure: error is ProfileFailure
              ? error.code
              : ProfileFailureCode.unexpected,
        );
      }
      return false;
    }
  }
}
