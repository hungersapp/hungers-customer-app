import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../authentication/providers/auth_provider.dart';
import '../../../serviceability/domain/geo_distance.dart';
import '../../domain/location_hints.dart';
import '../helpers/open_delivery_location_chooser.dart';
import '../providers/location_provider.dart';
import 'location_permission_dialog.dart';

/// The one line under the Home location header that tells the customer what
/// the app could not decide for them:
///
///  * the phone's current location cannot be read (permission denied,
///    location services off, no position) — with the fix, or manual selection;
///  * the delivery location they explicitly selected is far from where the
///    phone is now — with "Use current location". It is only an offer: an
///    explicit selection is never changed without the customer's tap.
///
/// Renders nothing otherwise. A saved address is never presented as the
/// current GPS location.
class LocationStatusBanner extends ConsumerWidget {
  const LocationStatusBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(deviceLocationStatusProvider);
    if (!status.isFailure) {
      return _farFromSelectionBanner(context, ref);
    }

    final String message;
    final String actionLabel;
    final VoidCallback action;
    switch (status) {
      case DeviceLocationStatus.permissionDeniedForever:
        message =
            'Location permission is off, so we can\'t show where you '
            'are now.';
        actionLabel = 'Enable';
        action = () => showLocationPermissionDialog(context);
      case DeviceLocationStatus.serviceDisabled:
        message = 'Location is turned off on this device.';
        actionLabel = 'Turn on';
        action = () => showLocationServiceDisabledDialog(context);
      case DeviceLocationStatus.permissionDenied:
        message = 'Allow location access to see restaurants near you.';
        actionLabel = 'Allow';
        action = () => _retry(ref);
      case DeviceLocationStatus.unavailable:
      case DeviceLocationStatus.unknown:
      case DeviceLocationStatus.available:
        message = 'We couldn\'t get your current location.';
        actionLabel = 'Retry';
        action = () => _retry(ref);
    }

    return _Banner(
      icon: Icons.location_off_outlined,
      message: message,
      actions: [
        TextButton(
          onPressed: () => openDeliveryLocationChooser(context, ref),
          style: _buttonStyle,
          child: const Text('Select location'),
        ),
        TextButton(
          onPressed: action,
          style: _buttonStyle,
          child: Text(actionLabel),
        ),
      ],
    );
  }

  /// GPS works and the customer's explicit selection is far from the phone:
  /// say so and offer the current location. Nothing changes unless tapped.
  Widget _farFromSelectionBanner(BuildContext context, WidgetRef ref) {
    final userId = ref.watch(currentUserIdProvider);
    final device = ref.watch(currentGpsLocationProvider);
    final active = userId == null
        ? null
        : ref.watch(userLocationProvider(userId)).valueOrNull;
    if (userId == null ||
        device == null ||
        active == null ||
        !active.isExplicitSelection) {
      return const SizedBox.shrink();
    }
    final km = GeoDistance.calculateDistanceKm(
      latitude1: device.latitude,
      longitude1: device.longitude,
      latitude2: active.latitude,
      longitude2: active.longitude,
    );
    if (km == null || km < LocationHints.farFromDeviceKm) {
      return const SizedBox.shrink();
    }

    return _Banner(
      icon: Icons.info_outline_rounded,
      message:
          'This delivery location is ${GeoDistance.formatKmLabel(km)} from '
          'where you are now.',
      actions: [
        TextButton(
          onPressed: () => _useCurrentLocation(ref, userId),
          style: _buttonStyle,
          child: const Text('Use current location'),
        ),
      ],
    );
  }

  static final ButtonStyle _buttonStyle = TextButton.styleFrom(
    foregroundColor: AppColors.primary,
    minimumSize: const Size(0, 32),
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
  );

  void _retry(WidgetRef ref) {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) {
      return;
    }
    ref
        .read(locationSetupProvider.notifier)
        .refreshCurrentLocation(userId, force: true);
  }

  Future<void> _useCurrentLocation(WidgetRef ref, String userId) async {
    try {
      await ref.read(locationSetupProvider.notifier).useCurrentLocation(userId);
    } catch (_) {
      // GPS could not be read: the selection stays, and the status banner
      // now says why.
    }
  }
}

class _Banner extends StatelessWidget {
  const _Banner({
    required this.icon,
    required this.message,
    required this.actions,
  });

  final IconData icon;
  final String message;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: Container(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.xs,
          AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: AppColors.warning.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(AppRadii.chip),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Icon(icon, size: 18, color: AppColors.textPrimary),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    message,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: actions),
          ],
        ),
      ),
    );
  }
}
