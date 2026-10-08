import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('bunny scooter marker keeps the bunny, the scooter, and a clear background', () async {
    final data = await rootBundle.load('assets/images/tukkito_bunny_scooter.png');
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    final frame = await codec.getNextFrame();
    final image = frame.image;
    expect(image.width, image.height);
    expect(image.width, greaterThanOrEqualTo(256));

    final raw = await image.toByteData();
    expect(raw, isNotNull);
    final pixels = raw!.buffer.asUint8List();
    var transparent = 0;
    var fur = 0;
    var orange = 0;
    var edgeOpaque = 0;
    final width = image.width;
    final height = image.height;
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final index = (y * width + x) * 4;
        final red = pixels[index];
        final green = pixels[index + 1];
        final blue = pixels[index + 2];
        final alpha = pixels[index + 3];
        if (alpha < 16) {
          transparent++;
          continue;
        }
        if (x < 6 || y < 6 || x >= width - 6 || y >= height - 6) {
          edgeOpaque++;
        }
        if (red > 210 && green > 210 && blue > 210) {
          fur++;
        }
        if (red > 170 && green > 60 && green < 200 && blue < 130) {
          orange++;
        }
      }
    }

    expect(transparent, greaterThan(fur + orange));
    expect(fur, greaterThan(400), reason: 'the bunny must be visible, not an orange blob');
    expect(orange, greaterThan(400), reason: 'the scooter must be visible');
    expect(edgeOpaque, 0, reason: 'ears, wheels, and handlebars must sit inside the frame');
    image.dispose();
  });
}
