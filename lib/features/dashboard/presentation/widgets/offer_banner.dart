import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';

class OfferBanner extends StatelessWidget {
  const OfferBanner({super.key});

  static const String _assetPath = 'assets/images/home_banner_good_food.png';
  static const double _aspectRatio = 1942 / 809;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        AppSpacing.sm,
        AppSpacing.page,
        AppSpacing.xl,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadii.banner),
          boxShadow: const [
            BoxShadow(
              color: AppColors.shadow,
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadii.banner),
          child: AspectRatio(
            aspectRatio: _aspectRatio,
            child: Image.asset(
              _assetPath,
              fit: BoxFit.contain,
              alignment: Alignment.center,
              width: double.infinity,
              filterQuality: FilterQuality.medium,
              semanticLabel:
                  'Tukkito promotional banner: Good Food Brighter Days',
              errorBuilder: (_, _, _) {
                return const ColoredBox(
                  color: AppColors.surface,
                  child: Center(
                    child: Icon(
                      Icons.broken_image_outlined,
                      color: AppColors.textSecondary,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
