import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart'
    hide LocationServiceDisabledException;

import '../../domain/entities/user_location.dart';
import '../../domain/exceptions/location_exception.dart';

/// Wraps device GPS and reverse geocoding APIs.
class DeviceLocationService {
  const DeviceLocationService();

  /// Ensures location permission is granted.
  ///
  /// Throws [LocationPermissionPermanentlyDeniedException] when the user has
  /// permanently denied permission, or [LocationPermissionDeniedException]
  /// when permission is denied.
  Future<void> ensurePermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw const LocationServiceDisabledException();
    }

    var permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.deniedForever) {
      throw const LocationPermissionPermanentlyDeniedException();
    }

    if (permission == LocationPermission.denied) {
      throw const LocationPermissionDeniedException();
    }
  }

  /// Returns the device's current GPS coordinates.
  Future<({double latitude, double longitude})> getCurrentCoordinates() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 30),
        ),
      );
      if (kDebugMode) {
        debugPrint(
          'TUKKITO_DISCOVERY gps lat=${position.latitude} '
          'lng=${position.longitude} accuracy_m=${position.accuracy} '
          'isMocked=${position.isMocked}',
        );
      }

      return (latitude: position.latitude, longitude: position.longitude);
    } catch (_) {
      throw const LocationPositionUnavailableException();
    }
  }

  /// Resolves [latitude] and [longitude] into city/state/area via reverse
  /// geocoding.
  Future<({String city, String state, String? pincode, String area})>
  reverseGeocode({required double latitude, required double longitude}) async {
    try {
      final placemarks = await placemarkFromCoordinates(latitude, longitude);

      if (placemarks.isEmpty) {
        throw const LocationGeocodingException();
      }

      final placemark = placemarks.first;
      final city = _resolveCity(placemark);
      final state = placemark.administrativeArea?.trim() ?? '';
      final pincode = _resolvePincode(placemark);
      final area = placemark.subLocality?.trim().isNotEmpty == true
          ? placemark.subLocality!.trim()
          : (placemark.thoroughfare?.trim() ?? '');

      if (city.isEmpty || state.isEmpty) {
        throw const LocationGeocodingException();
      }

      return (city: city, state: state, pincode: pincode, area: area);
    } on LocationGeocodingException {
      rethrow;
    } catch (_) {
      throw const LocationGeocodingException();
    }
  }

  /// Obtains GPS coordinates and reverse geocodes them into a [UserLocation].
  Future<UserLocation> getCurrentUserLocation() async {
    await ensurePermission();

    final coordinates = await getCurrentCoordinates();
    final address = await reverseGeocode(
      latitude: coordinates.latitude,
      longitude: coordinates.longitude,
    );

    return UserLocation(
      latitude: coordinates.latitude,
      longitude: coordinates.longitude,
      city: address.city,
      state: address.state,
      pincode: address.pincode,
      area: address.area,
      updatedAt: DateTime.now(),
    );
  }

  /// Emits a [UserLocation] after a meaningful GPS move.
  ///
  /// The OS-level distance filter (200 m by default) is what throttles this
  /// — not a timer. Failed reverse-geocodes are skipped. This stream never
  /// writes Firestore; location setup decides whether a reading is worth
  /// persisting.
  Stream<UserLocation> watchSignificantMoves({
    int distanceFilterMeters = 200,
  }) async* {
    await ensurePermission();
    await for (final position in Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: LocationAccuracy.medium,
        distanceFilter: distanceFilterMeters,
      ),
    )) {
      if (kDebugMode) {
        debugPrint(
          'TUKKITO_DISCOVERY gps_stream lat=${position.latitude} '
          'lng=${position.longitude} accuracy_m=${position.accuracy}',
        );
      }
      try {
        final address = await reverseGeocode(
          latitude: position.latitude,
          longitude: position.longitude,
        );
        yield UserLocation(
          latitude: position.latitude,
          longitude: position.longitude,
          city: address.city,
          state: address.state,
          pincode: address.pincode,
          area: address.area,
          updatedAt: DateTime.now(),
        );
      } catch (_) {
        // Keep listening; a single failed geocode is not a new destination.
      }
    }
  }

  /// Forward-geocodes a free-text area / address query (no map SDK).
  Future<UserLocation> searchArea(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      throw const LocationGeocodingException();
    }

    try {
      final locations = await locationFromAddress(trimmed);
      if (locations.isEmpty) {
        throw const LocationGeocodingException();
      }
      final first = locations.first;
      final address = await reverseGeocode(
        latitude: first.latitude,
        longitude: first.longitude,
      );
      return UserLocation(
        latitude: first.latitude,
        longitude: first.longitude,
        city: address.city,
        state: address.state,
        pincode: address.pincode,
        area: address.area.isNotEmpty ? address.area : trimmed,
        updatedAt: DateTime.now(),
      );
    } on LocationGeocodingException {
      rethrow;
    } catch (_) {
      throw const LocationGeocodingException();
    }
  }

  /// How many matches [searchPlaces] returns at most.
  static const int maxSearchResults = 5;

  /// Forward-geocodes [query] into every distinct place the geocoder offers
  /// (up to [maxSearchResults]), for the selector's search-results list.
  /// Matches whose address cannot be resolved are skipped. Returns an empty
  /// list when nothing is found; throws [LocationGeocodingException] only
  /// when the lookup itself fails.
  Future<List<UserLocation>> searchPlaces(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      return const [];
    }

    final List<Location> matches;
    try {
      matches = await locationFromAddress(trimmed);
    } on NoResultFoundException {
      return const [];
    } catch (_) {
      throw const LocationGeocodingException();
    }

    final results = <UserLocation>[];
    final seen = <String>{};
    for (final match in matches) {
      if (results.length >= maxSearchResults) {
        break;
      }
      try {
        final address = await reverseGeocode(
          latitude: match.latitude,
          longitude: match.longitude,
        );
        final place = UserLocation(
          latitude: match.latitude,
          longitude: match.longitude,
          city: address.city,
          state: address.state,
          pincode: address.pincode,
          area: address.area.isNotEmpty ? address.area : trimmed,
          updatedAt: DateTime.now(),
        );
        // The geocoder can return the same place more than once.
        if (seen.add('${place.area}|${place.city}|${place.pincode}')) {
          results.add(place);
        }
      } catch (_) {
        // This match has no usable address; the others may.
      }
    }
    return results;
  }

  String _resolveCity(Placemark placemark) {
    final candidates = [
      placemark.locality,
      placemark.subAdministrativeArea,
      placemark.subLocality,
    ];

    for (final candidate in candidates) {
      final value = candidate?.trim();
      if (value != null && value.isNotEmpty) {
        return value;
      }
    }

    return '';
  }

  String? _resolvePincode(Placemark placemark) {
    final postal = placemark.postalCode?.replaceAll(RegExp(r'\s+'), '') ?? '';
    if (RegExp(r'^\d{6}$').hasMatch(postal)) {
      return postal;
    }
    return null;
  }
}
