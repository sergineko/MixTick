import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:mixtick/features/profile/data/avatar_processor.dart';
import 'package:mixtick/features/profile/domain/user_profile.dart';

void main() {
  test(
    'Avatar reencodificado elimina metadatos de origen y mantiene dimensiones',
    () async {
      final source = img.Image(width: 8, height: 6)
        ..textData = {'private': 'private-metadata-fixture'};
      source.setPixelRgb(0, 0, 200, 20, 30);
      final prepared = await prepareAvatar(img.encodePng(source));
      final decoded = img.decodeJpg(prepared)!;
      expect(decoded.width, 8);
      expect(decoded.height, 6);
      expect(
        String.fromCharCodes(prepared).contains('private-metadata-fixture'),
        isFalse,
      );
      expect(decoded.textData?.isEmpty ?? true, isTrue);
      expect(decoded.exif.isEmpty, isTrue);
    },
  );
  test('Avatar corrupto con cabecera válida no llega a Storage', () async {
    await expectLater(
      prepareAvatar(Uint8List.fromList([255, 216, 255, 0, 0, 0])),
      throwsA(isA<ProfileFailure>()),
    );
  });
}
