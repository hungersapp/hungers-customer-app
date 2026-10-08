import 'package:flutter/material.dart';

import '../../../../core/widgets/sized_network_image.dart';
import 'restaurant_image_placeholder.dart';

/// Displays the restaurant cover image with loading and error states.
class RestaurantCoverImage extends StatelessWidget {
  const RestaurantCoverImage({
    super.key,
    required this.imageUrl,
    this.aspectRatio = 16 / 9,
    this.borderRadius = const BorderRadius.vertical(top: Radius.circular(16)),
  });

  final String imageUrl;
  final double aspectRatio;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: borderRadius,
      child: AspectRatio(aspectRatio: aspectRatio, child: _buildImage()),
    );
  }

  Widget _buildImage() {
    if (imageUrl.isEmpty) {
      return const RestaurantImagePlaceholder();
    }

    return SizedNetworkImage(
      url: imageUrl,
      fit: BoxFit.cover,
      placeholder: const RestaurantImagePlaceholder(showProgress: true),
      error: const RestaurantImagePlaceholder(),
    );
  }
}
