import 'package:flutter/material.dart';

/// Network image sized to the layout box so a 4K original is not decoded
/// at full resolution for a card. Original URL is unchanged (fallback).
class SizedNetworkImage extends StatelessWidget {
  const SizedNetworkImage({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    this.width,
    this.height,
    this.placeholder,
    this.error,
  });

  final String url;
  final BoxFit fit;
  final Alignment alignment;
  final double? width;
  final double? height;
  final Widget? placeholder;
  final Widget? error;

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.maybeDevicePixelRatioOf(context) ?? 1.0;
    return LayoutBuilder(
      builder: (context, constraints) {
        final logicalWidth = width ??
            (constraints.maxWidth.isFinite ? constraints.maxWidth : 120);
        final logicalHeight = height ??
            (constraints.maxHeight.isFinite ? constraints.maxHeight : 120);
        final cacheWidth = (logicalWidth * dpr).round().clamp(40, 1200);
        final cacheHeight = (logicalHeight * dpr).round().clamp(40, 1200);
        return Image.network(
          url,
          fit: fit,
          alignment: alignment,
          width: width ?? double.infinity,
          height: height ?? double.infinity,
          cacheWidth: cacheWidth,
          cacheHeight: cacheHeight,
          filterQuality: FilterQuality.low,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) {
              return child;
            }
            return placeholder ?? child;
          },
          errorBuilder: (_, _, _) => error ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
