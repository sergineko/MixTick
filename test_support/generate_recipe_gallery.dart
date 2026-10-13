// Controlled encoder fixture, not a production/demo recipe photograph.
import 'dart:io';

import 'package:image/image.dart' as img;

void main() {
  final image = img.Image(width: 800, height: 600);
  image.clear(img.ColorRgb8(235, 225, 200));
  img.fillCircle(
    image,
    x: 400,
    y: 300,
    radius: 240,
    color: img.ColorRgb8(245, 245, 245),
  );
  img.fillCircle(
    image,
    x: 400,
    y: 300,
    radius: 205,
    color: img.ColorRgb8(200, 80, 50),
  );
  for (var i = 0; i < 8; i++) {
    img.fillCircle(
      image,
      x: 280 + (i % 4) * 80,
      y: 220 + (i ~/ 4) * 120,
      radius: 25,
      color: img.ColorRgb8(55, 130, 65),
    );
  }
  File('.tooling/phase04-gallery.png').writeAsBytesSync(img.encodePng(image));
  stdout.writeln('Controlled 800x600 PNG gallery fixture generated');
}
