import 'package:customer_app/features/location/data/models/user_location_model.dart';

/// Emulates the `users/{uid}` document write/read semantics that
/// [LocationFirestoreDatasource] depends on, so tests can cover them without a
/// Firestore emulator.
///
/// The important behaviour reproduced here is `SetOptions(merge: true)`:
/// "Fields omitted from the set() call remain untouched" — for map fields that
/// merge happens key by key, which is exactly why `saveDeliveryPincode` can
/// write `{'location': {'pincode': ...}}` without destroying the rest of the
/// saved address.
class FakeUserLocationDocument {
  FakeUserLocationDocument([Map<String, dynamic>? initialData])
    : data = initialData ?? <String, dynamic>{};

  Map<String, dynamic> data;

  /// Mirrors `LocationFirestoreDatasource.saveLocation`.
  void saveLocation(
    UserLocationModel location, {
    bool clearStaleAddressDetails = false,
  }) {
    setWithMerge({
      'location': location.toMap(
        clearStaleAddressDetails: clearStaleAddressDetails,
      ),
      if (location.pincode != null)
        'deliveryPincode': location.pincode
      else if (clearStaleAddressDetails)
        'deliveryPincode': null,
    });
  }

  /// Mirrors `LocationFirestoreDatasource.saveDeliveryPincode`.
  void saveDeliveryPincode(String pincode) {
    setWithMerge({
      'deliveryPincode': pincode,
      'location': {'pincode': pincode},
    });
  }

  /// Mirrors `LocationFirestoreDatasource.getLocation`.
  UserLocationModel? getLocation() {
    final locationData = data['location'];
    if (locationData is! Map<String, dynamic>) {
      return null;
    }
    if (locationData['latitude'] is! num || locationData['longitude'] is! num) {
      return null;
    }
    return UserLocationModel.fromMap(
      locationData,
      fallbackPincode: readPincode(data['deliveryPincode']),
    );
  }

  /// The raw nested `location.pincode` value, including an explicit null.
  Object? get rawLocationPincode {
    final locationData = data['location'];
    return locationData is Map<String, dynamic>
        ? locationData['pincode']
        : null;
  }

  /// Mirrors `LocationFirestoreDatasource.getDeliveryPincode`.
  String? get deliveryPincode {
    final locationData = data['location'];
    if (locationData is Map<String, dynamic>) {
      final fromLocation = readPincode(locationData['pincode']);
      if (fromLocation != null) {
        return fromLocation;
      }
    }
    return readPincode(data['deliveryPincode']);
  }

  void setWithMerge(Map<String, dynamic> payload) {
    data = _merge(data, payload);
  }

  static Map<String, dynamic> _merge(
    Map<String, dynamic> existing,
    Map<String, dynamic> payload,
  ) {
    final merged = Map<String, dynamic>.from(existing);
    payload.forEach((key, value) {
      final previous = merged[key];
      if (value is Map<String, dynamic> && previous is Map<String, dynamic>) {
        merged[key] = _merge(previous, value);
      } else {
        merged[key] = value;
      }
    });
    return merged;
  }

  static String? readPincode(Object? value) {
    if (value is! String) {
      return null;
    }
    final trimmed = value.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(trimmed)) {
      return null;
    }
    return trimmed;
  }

  /// A document as written by the manual address editor for Madurai.
  static FakeUserLocationDocument maduraiManualAddress() {
    final document = FakeUserLocationDocument();
    document.saveLocation(
      UserLocationModel(
        latitude: 9.9195,
        longitude: 78.1193,
        city: 'Madurai',
        state: 'Tamil Nadu',
        pincode: '625001',
        doorNumber: '12A',
        street: 'Bypass Road',
        area: 'Vandiyur',
        updatedAt: DateTime(2026, 1, 1),
      ),
    );
    return document;
  }

  /// A fresh Chennai GPS reading whose reverse geocoding produced no postal
  /// code (the case this regression guards).
  static UserLocationModel chennaiGpsWithoutPincode() {
    return UserLocationModel(
      latitude: 13.0827,
      longitude: 80.2707,
      city: 'Chennai',
      state: 'Tamil Nadu',
      updatedAt: DateTime(2026, 2, 1),
    );
  }
}
