import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Full Tukkito bunny riding an orange scooter, facing north.
///
/// One transparent PNG is scaled once and cached. Marker rotation turns
/// the bunny and the scooter together. The anchor is the scooter center,
/// not the ears.
class RiderMarkerIconFactory {
  const RiderMarkerIconFactory._();

  static const String assetPath = 'assets/images/tukkito_bunny_scooter.png';

  /// Logical size on the map. Large enough to read the bunny, small
  /// enough not to cover the street.
  static const double defaultSizePx = 76;

  /// Center of the scooter body on the transparent PNG.
  static const Offset anchor = Offset(0.50, 0.50);

  static Future<BitmapDescriptor>? _cached;

  static Future<BitmapDescriptor> build({double sizePx = defaultSizePx}) {
    return _cached ??= _load(sizePx);
  }

  static Future<BitmapDescriptor> _load(double sizePx) async {
    final data = await rootBundle.load(assetPath);
    final ratio = ui.PlatformDispatcher.instance.implicitView?.devicePixelRatio ?? 3;
    final target = (sizePx * ratio).round();
    final codec = await ui.instantiateImageCodec(
      data.buffer.asUint8List(),
      targetWidth: target,
      targetHeight: target,
    );
    final frame = await codec.getNextFrame();
    final bytes = await frame.image.toByteData(format: ui.ImageByteFormat.png);
    frame.image.dispose();
    if (bytes == null) {
      return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange);
    }
    return BitmapDescriptor.bytes(
      bytes.buffer.asUint8List(),
      width: sizePx,
      height: sizePx,
    );
  }
}
