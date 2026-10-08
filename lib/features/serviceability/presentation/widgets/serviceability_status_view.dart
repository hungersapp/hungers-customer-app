import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../providers/serviceability_provider.dart';

/// What the Home restaurant section shows before / instead of restaurants,
/// for the customer's selected delivery location.
class ServiceabilityStatusView extends StatelessWidget {
  const ServiceabilityStatusView({
    super.key,
    required this.state,
    required this.onRetry,
    required this.onChangeLocation,
  });

  final ServiceabilityState state;
  final VoidCallback onRetry;

  /// Opens the delivery-location chooser (current location, or search any
  /// place).
  final VoidCallback onChangeLocation;

  @override
  Widget build(BuildContext context) {
    switch (state.status) {
      case ServiceabilityUiStatus.initial:
        return _StatusCard(
          icon: Icons.my_location_rounded,
          iconColor: AppColors.primary,
          title: 'Choose your delivery location',
          message:
              'Use your current location or search any area to see the '
              'restaurants that deliver there.',
          actionLabel: 'Choose location',
          actionIcon: Icons.edit_location_alt_outlined,
          onAction: onChangeLocation,
        );
      case ServiceabilityUiStatus.invalidPincode:
        return _StatusCard(
          icon: Icons.my_location_rounded,
          iconColor: AppColors.primary,
          title: 'Choose your delivery location',
          message:
              'We could not read a valid pincode for this location. Please '
              'choose your location again.',
          actionLabel: 'Choose location',
          actionIcon: Icons.edit_location_alt_outlined,
          onAction: onChangeLocation,
        );
      case ServiceabilityUiStatus.checking:
        return const _StatusCard(
          icon: Icons.hourglass_top_rounded,
          iconColor: AppColors.info,
          title: 'Checking availability...',
          message: 'Please wait while we check your delivery area.',
        );
      case ServiceabilityUiStatus.serviceable:
        return const SizedBox.shrink();
      case ServiceabilityUiStatus.notServiceable:
        return _StatusCard(
          icon: Icons.location_off_rounded,
          iconColor: AppColors.warning,
          title: 'Sorry, no restaurants available in this location.',
          message: 'Try choosing a different delivery location.',
          actionLabel: 'Change location',
          actionIcon: Icons.edit_location_alt_outlined,
          onAction: onChangeLocation,
        );
      case ServiceabilityUiStatus.error:
        return _StatusCard(
          icon: Icons.wifi_off_rounded,
          iconColor: AppColors.error,
          title: 'Unable to check availability. Please try again.',
          message: 'This is not a coverage decision. Please retry.',
          actionLabel: 'Retry',
          actionIcon: Icons.refresh_rounded,
          onAction: onRetry,
        );
    }
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.message,
    this.actionLabel,
    this.actionIcon,
    this.onAction,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String? message;
  final String? actionLabel;
  final IconData? actionIcon;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        AppSpacing.sm,
        AppSpacing.page,
        AppSpacing.lg,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadii.card),
          border: Border.all(color: AppColors.border),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            AppSpacing.md,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 28, color: iconColor),
              const SizedBox(height: AppSpacing.sm),
              Text(
                title,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleSmall,
              ),
              if (message != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  message!,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium,
                ),
              ],
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: AppSpacing.lg),
                FilledButton.icon(
                  onPressed: onAction,
                  icon: Icon(actionIcon ?? Icons.refresh_rounded, size: 18),
                  label: Text(actionLabel!),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
