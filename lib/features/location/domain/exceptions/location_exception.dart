/// Base exception for location-related failures.
class LocationException implements Exception {
  const LocationException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Thrown when the user permanently denied location permission.
class LocationPermissionPermanentlyDeniedException extends LocationException {
  const LocationPermissionPermanentlyDeniedException()
    : super(
        'Location permission is permanently denied. '
        'Please enable it in app settings.',
      );
}

/// Thrown when location permission is denied by the user.
class LocationPermissionDeniedException extends LocationException {
  const LocationPermissionDeniedException()
    : super('Location permission was denied.');
}

/// Thrown when device location services are disabled.
class LocationServiceDisabledException extends LocationException {
  const LocationServiceDisabledException()
    : super('Device location services are disabled.');
}

/// Thrown when reverse geocoding fails to resolve city and state.
class LocationGeocodingException extends LocationException {
  const LocationGeocodingException()
    : super('Unable to determine your city and state from GPS coordinates.');
}

/// Thrown when GPS coordinates cannot be obtained.
class LocationPositionUnavailableException extends LocationException {
  const LocationPositionUnavailableException()
    : super('Unable to obtain your current GPS coordinates.');
}
