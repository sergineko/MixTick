import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import '../domain/profile_repository.dart';
import '../domain/user_profile.dart';

Future<Uint8List> prepareAvatar(Uint8List bytes) => compute(_prepare, bytes);
Uint8List _prepare(Uint8List bytes) {
  try {
    AvatarImage.extension(bytes);
    // This setting belongs to this short-lived worker isolate only.
    img.Decoder.defaultMaxPixels = 16000000;
    final decoder = img.findDecoderForData(bytes);
    final info = decoder?.startDecode(bytes);
    if (info == null ||
        info.width <= 0 ||
        info.height <= 0 ||
        info.width * info.height > 16000000) {
      throw const ProfileFailure(ProfileFailureCode.invalidPhoto);
    }
    final frame = decoder!.decodeFrame(0);
    if (frame == null) {
      throw const ProfileFailure(ProfileFailureCode.invalidPhoto);
    }
    var image = img.bakeOrientation(frame);
    if (image.width > 1024 || image.height > 1024) {
      final ratio =
          1024 / (image.width > image.height ? image.width : image.height);
      image = img.copyResize(
        image,
        width: (image.width * ratio).round(),
        height: (image.height * ratio).round(),
      );
    }
    // Copy pixels into a new RGB image: no EXIF/GPS, text, ICC or animation.
    final clean = img.Image(width: image.width, height: image.height);
    for (final pixel in image) {
      final alpha = pixel.aNormalized;
      clean.setPixelRgb(
        pixel.x,
        pixel.y,
        ((pixel.rNormalized * alpha + 1 - alpha) * 255).round(),
        ((pixel.gNormalized * alpha + 1 - alpha) * 255).round(),
        ((pixel.bNormalized * alpha + 1 - alpha) * 255).round(),
      );
    }
    final output = img.encodeJpg(clean, quality: 85);
    if (output.length > AvatarImage.maximumBytes) {
      throw const ProfileFailure(ProfileFailureCode.invalidPhoto);
    }
    return output;
  } catch (_) {
    throw const ProfileFailure(ProfileFailureCode.invalidPhoto);
  }
}
