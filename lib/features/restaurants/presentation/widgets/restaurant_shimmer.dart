import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';

/// Home loading placeholders matching the restaurant card layout.
class RestaurantShimmer extends StatelessWidget {
  const RestaurantShimmer({super.key, this.itemCount = 2});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
      child: Column(
        children: List.generate(
          itemCount,
          (index) => Padding(
            padding: EdgeInsets.only(
              bottom: index == itemCount - 1 ? 0 : AppSpacing.md,
            ),
            child: const _RestaurantShimmerCard(),
          ),
        ),
      ),
    );
  }
}

class _RestaurantShimmerCard extends StatelessWidget {
  const _RestaurantShimmerCard();

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.border,
      highlightColor: AppColors.background,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadii.card),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: ColoredBox(color: Colors.white),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Container(height: 16, color: Colors.white),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Container(
                        height: 22,
                        width: 48,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(AppRadii.chip),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Container(height: 12, width: 140, color: Colors.white),
                  const SizedBox(height: AppSpacing.md),
                  Container(height: 12, width: 100, color: Colors.white),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
