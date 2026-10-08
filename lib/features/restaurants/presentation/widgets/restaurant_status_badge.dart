import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Displays whether a restaurant is open, closed, or closing soon.
class RestaurantStatusBadge extends StatelessWidget {
  const RestaurantStatusBadge({
    super.key,
    required this.isOpen,
    this.isClosingSoon = false,
  });

  final bool isOpen;
  final bool isClosingSoon;

  @override
  Widget build(BuildContext context) {
    final ({Color background, Color foreground, String label}) status;

    if (!isOpen) {
      status = (
        background: AppColors.error,
        foreground: AppColors.textLight,
        label: 'Closed',
      );
    } else if (isClosingSoon) {
      status = (
        background: AppColors.warning,
        foreground: AppColors.textPrimary,
        label: 'Closing Soon',
      );
    } else {
      status = (
        background: AppColors.success,
        foreground: AppColors.textLight,
        label: 'Open',
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: status.background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Text(
          status.label,
          style: TextStyle(
            color: status.foreground,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
