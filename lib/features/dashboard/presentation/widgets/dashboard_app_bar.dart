import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../authentication/providers/auth_provider.dart';
import '../../../location/domain/discovery_location_kind.dart';
import '../../../location/presentation/helpers/open_delivery_location_chooser.dart';
import '../../../location/presentation/providers/location_provider.dart';
import '../../../location/presentation/widgets/location_shimmer.dart';
import '../../../location/presentation/widgets/location_status_banner.dart';

class DashboardAppBar extends ConsumerWidget {
  const DashboardAppBar({super.key});

  static const String _unavailableLabel = 'Location unavailable';
  static const String _chooseLabel = 'Select your location';
  static const String _lastKnownLabel = 'Last known location';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final userId = authState.valueOrNull?.uid;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        AppSpacing.lg,
        AppSpacing.page,
        AppSpacing.md,
      ),
      child: Column(
        children: [
          _buildHeaderRow(context: context, ref: ref, userId: userId),
          const LocationStatusBanner(),
        ],
      ),
    );
  }

  Widget _buildHeaderRow({
    required BuildContext context,
    required WidgetRef ref,
    required String? userId,
  }) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.location_on_rounded,
                    color: AppColors.primary,
                    size: 18,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text('Deliver To', style: theme.textTheme.labelMedium),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              InkWell(
                onTap: () => openDeliveryLocationChooser(context, ref),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildLocationText(
                        ref: ref,
                        theme: theme,
                        userId: userId,
                      ),
                    ),
                    const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 22,
                      color: AppColors.textPrimary,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        InkWell(
          borderRadius: BorderRadius.circular(30),
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Notifications will be available soon.'),
              ),
            );
          },
          child: Container(
            height: 44,
            width: 44,
            decoration: BoxDecoration(
              color: AppColors.surface,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.border),
              boxShadow: const [
                BoxShadow(
                  color: AppColors.shadow,
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(
              Icons.notifications_none_rounded,
              size: 22,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLocationText({
    required WidgetRef ref,
    required ThemeData theme,
    required String? userId,
  }) {
    if (userId == null) {
      return Text(
        _unavailableLabel,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.titleMedium?.copyWith(
          color: AppColors.textSecondary,
        ),
      );
    }

    final locationState = ref.watch(userLocationProvider(userId));
    // When GPS cannot be read, a GPS-derived location is only where the phone
    // WAS: it is labelled as such, never as the current location.
    final gpsUnavailable = ref.watch(deviceLocationStatusProvider).isFailure;

    return locationState.when(
      data: (location) {
        if (location == null) {
          return Text(
            gpsUnavailable ? _chooseLabel : _unavailableLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleMedium?.copyWith(
              color: AppColors.textSecondary,
            ),
          );
        }

        final book = ref.watch(savedAddressBookProvider(userId)).valueOrNull;
        final presentation = DiscoveryLocationPresentation.from(
          location: location,
          book: book,
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              gpsUnavailable &&
                      presentation.kind == DiscoveryLocationKind.currentLocation
                  ? _lastKnownLabel
                  : presentation.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleMedium?.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
            if (presentation.subtitle.isNotEmpty)
              Text(
                presentation.subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
          ],
        );
      },
      loading: () => const LocationShimmer(),
      error: (_, _) => Text(
        _unavailableLabel,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.titleMedium?.copyWith(
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}
