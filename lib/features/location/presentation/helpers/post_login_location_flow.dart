import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/app_routes.dart';
import '../../domain/exceptions/location_exception.dart';
import '../providers/location_provider.dart';
import '../widgets/location_permission_dialog.dart';

/// Handles post-login location setup and navigation to the dashboard.
Future<void> handlePostLoginNavigation({
  required BuildContext context,
  required WidgetRef ref,
  required String userId,
}) async {
  if (!context.mounted) return;

  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const PopScope(
      canPop: false,
      child: Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Setting up your delivery location...'),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  try {
    await ref
        .read(locationSetupProvider.notifier)
        .setupLocationAfterLogin(userId);

    final setupState = ref.read(locationSetupProvider);

    setupState.whenOrNull(
      error: (error, _) async {
        if (!context.mounted) return;

        if (error is LocationPermissionPermanentlyDeniedException) {
          await showLocationPermissionDialog(context);
        } else if (error is LocationServiceDisabledException) {
          await showLocationServiceDisabledDialog(context);
        }
      },
    );
  } finally {
    if (context.mounted) {
      Navigator.of(context, rootNavigator: true).pop();
    }

    if (context.mounted) {
      ref.invalidate(userLocationProvider(userId));

      Navigator.pushReplacementNamed(context, AppRoutes.dashboard);
    }
  }
}
