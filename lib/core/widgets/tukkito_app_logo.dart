import 'package:flutter/material.dart';

/// Displays [assets/images/app_logo.png] cropped to the rounded Tukkito
/// tile only. The source file is 1254×1254 RGB; the orange rounded square
/// occupies x=41..1209, y=40..1210. Rows below y=1210 are the black margin
/// that contains the unwanted "DISCOVER • ORDER • ENJOY" caption.
///
/// Black pixels are treated as transparent so the rounded orange square is
/// preserved without a square letterbox around the corners.
class TukkitoAppLogo extends StatelessWidget {
  const TukkitoAppLogo({
    super.key,
    this.size = 120,
  });

  final double size;

  static const String assetPath = 'assets/images/app_logo.png';
  static const double _assetSize = 1254;

  /// Inclusive pixel bounds of the rounded orange tile, including
  /// anti-aliased edge pixels measured from the asset.
  static const double _cropLeft = 36;
  static const double _cropTop = 35;
  static const double _cropRight = 1213;
  static const double _cropBottom = 1210;

  static const double _visibleWidth = _cropRight - _cropLeft + 1;
  static const double _visibleHeight = _cropBottom - _cropTop + 1;
  static const double _widthFactor = _visibleWidth / _assetSize;
  static const double _heightFactor = _visibleHeight / _assetSize;

  static const double _alignmentX =
      2 * (_cropLeft / (_assetSize - _visibleWidth)) - 1;
  static const double _alignmentY =
      2 * (_cropTop / (_assetSize - _visibleHeight)) - 1;

  /// Keeps RGB, sets alpha from RGB sum so near-black becomes transparent.
  static const ColorFilter _knockoutBlack = ColorFilter.matrix(<double>[
    1, 0, 0, 0, 0,
    0, 1, 0, 0, 0,
    0, 0, 1, 0, 0,
    1, 1, 1, 0, 0,
  ]);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: ClipRect(
        child: ColorFiltered(
          colorFilter: _knockoutBlack,
          child: Align(
            alignment: const Alignment(_alignmentX, _alignmentY),
            widthFactor: _widthFactor,
            heightFactor: _heightFactor,
            child: Image.asset(
              assetPath,
              width: size / _widthFactor,
              height: size / _heightFactor,
              fit: BoxFit.fill,
              filterQuality: FilterQuality.medium,
              gaplessPlayback: true,
            ),
          ),
        ),
      ),
    );
  }
}
