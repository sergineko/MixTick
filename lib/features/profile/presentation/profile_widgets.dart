import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/localization/generated/app_localizations.dart';
import '../domain/user_profile.dart';
import 'profile_providers.dart';

String profileErrorMessage(AppLocalizations s, Object error) {
  final code = error is ProfileFailure
      ? error.code
      : ProfileFailureCode.unexpected;
  return switch (code) {
    ProfileFailureCode.network => s.networkError,
    ProfileFailureCode.usernameTaken => s.usernameTaken,
    ProfileFailureCode.conflict => s.profileConflict,
    ProfileFailureCode.forbidden => s.profileForbidden,
    ProfileFailureCode.invalidPhoto => s.invalidPhoto,
    ProfileFailureCode.unexpected => s.operationError,
  };
}

class ProfileAvatar extends ConsumerWidget {
  const ProfileAvatar({this.path, super.key});
  final String? path;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppLocalizations.of(context);
    if (path == null) {
      return CircleAvatar(
        radius: 48,
        child: Icon(Icons.person_outline, size: 48, semanticLabel: s.noPhoto),
      );
    }
    return ref
        .watch(avatarProvider(path!))
        .when(
          skipLoadingOnRefresh: false,
          data: (bytes) => ClipOval(
            child: Image.memory(
              bytes,
              width: 96,
              height: 96,
              fit: BoxFit.cover,
              semanticLabel: s.profilePhoto,
              errorBuilder: (_, _, _) => Text(s.photoUnavailable),
            ),
          ),
          loading: () => Semantics(
            label: s.loadingPhoto,
            child: const SizedBox(
              width: 96,
              height: 96,
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
          error: (_, _) => SizedBox(
            width: 160,
            child: Column(
              children: [
                Text(s.photoUnavailable),
                TextButton(
                  onPressed: () => ref.invalidate(avatarProvider(path!)),
                  child: Text(s.retry),
                ),
              ],
            ),
          ),
        );
  }
}
