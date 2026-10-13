import 'dart:typed_data';

import 'user_profile.dart';

abstract interface class ProfileRepository {
  Future<UserProfile?> loadOwn();
  Future<PublicProfile?> loadPublic(String username);
  Future<UserProfile> save({
    required String username,
    required String displayName,
    UserProfile? previous,
    String? avatarPath,
  });
  Future<String> uploadAvatar(Uint8List bytes);
  Future<Uint8List> downloadAvatar(String path);
  Future<void> removeAvatar(String path);
}

class AvatarImage {
  static const maximumBytes = 2097152;
  static String extension(Uint8List bytes) {
    if (bytes.isEmpty || bytes.length > maximumBytes) {
      throw const ProfileFailure(ProfileFailureCode.invalidPhoto);
    }
    if (bytes.length >= 3 &&
        bytes[0] == 255 &&
        bytes[1] == 216 &&
        bytes[2] == 255) {
      return 'jpg';
    }
    if (bytes.length >= 8 &&
        bytes.take(8).join(',') == '137,80,78,71,13,10,26,10') {
      return 'png';
    }
    if (bytes.length >= 12 &&
        String.fromCharCodes(bytes.take(4)) == 'RIFF' &&
        String.fromCharCodes(bytes.skip(8).take(4)) == 'WEBP') {
      return 'webp';
    }
    throw const ProfileFailure(ProfileFailureCode.invalidPhoto);
  }
}
