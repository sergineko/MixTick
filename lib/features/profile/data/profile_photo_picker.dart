import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import '../domain/profile_repository.dart';
import '../domain/user_profile.dart';

class ProfilePhotoPicker {
  Future<Uint8List?> pick() async {
    final picker = ImagePicker();
    final lost = defaultTargetPlatform == TargetPlatform.android
        ? await picker.retrieveLostData()
        : null;
    final image =
        lost?.files?.firstOrNull ??
        await picker.pickImage(
          source: ImageSource.gallery,
          maxWidth: 1024,
          maxHeight: 1024,
          imageQuality: 80,
          requestFullMetadata: false,
        );
    if (image == null) return null;
    if (await image.length() > AvatarImage.maximumBytes) {
      throw const ProfileFailure(ProfileFailureCode.invalidPhoto);
    }
    final bytes = await image.readAsBytes();
    AvatarImage.extension(bytes);
    return bytes;
  }
}
