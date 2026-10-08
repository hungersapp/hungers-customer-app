import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:customer_app/core/widgets/sized_network_image.dart';

void main() {
  testWidgets('decodes a card image at layout size, not full original pixels', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MediaQuery(
        data: MediaQueryData(devicePixelRatio: 2),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: SizedNetworkImage(
            url: 'https://example.com/hero.png',
            width: 80,
            height: 80,
          ),
        ),
      ),
    );

    final image = tester.widget<Image>(find.byType(Image));
    expect(image.image, isA<ResizeImage>());
    final resized = image.image as ResizeImage;
    expect(resized.width, 160);
    expect(resized.height, 160);
    expect(resized.imageProvider, isA<NetworkImage>());
    expect(
      (resized.imageProvider as NetworkImage).url,
      'https://example.com/hero.png',
    );
  });

  testWidgets('falls back to the original URL when loading fails', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MediaQuery(
        data: MediaQueryData(devicePixelRatio: 1),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: SizedNetworkImage(
            url: 'https://example.com/missing.png',
            width: 48,
            height: 48,
            error: SizedBox(key: Key('fallback')),
          ),
        ),
      ),
    );

    expect(find.byType(Image), findsOneWidget);
    final image = tester.widget<Image>(find.byType(Image));
    expect(image.image, isA<ResizeImage>());
    expect(
      ((image.image as ResizeImage).imageProvider as NetworkImage).url,
      'https://example.com/missing.png',
    );
  });
}
