import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

/// Shows a dialog directing the user to enable location in app settings.
Future<void> showLocationPermissionDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      return AlertDialog(
        title: const Text('Location Permission Required'),
        content: const Text(
          'Location access is required to show nearby restaurants and deliver '
          'food to your address. Please enable location permission in app '
          'settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Not Now'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              await Geolocator.openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      );
    },
  );
}

/// Shows a dialog when device location services are disabled.
Future<void> showLocationServiceDisabledDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      return AlertDialog(
        title: const Text('Location Services Disabled'),
        content: const Text(
          'Please enable location services on your device to use delivery '
          'location features.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Not Now'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              await Geolocator.openLocationSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      );
    },
  );
}
